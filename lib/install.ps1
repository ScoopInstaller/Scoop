function nightly_version($date, $quiet = $false) {
    $date_str = $date.tostring("yyyyMMdd")
    if (!$quiet) {
        warn "this is a nightly version: downloaded files won't be verified"
    }
    "nightly-$date_str"
}

function install_app($app, $architecture, $global) {
    $app, $bucket = app $app
    $app, $manifest, $bucket, $url = locate $app $bucket
    $use_cache = $true
    $check_hash = $true

    if(!$manifest) {
        abort "couldn't find manifest for $app$(if($url) { " at the URL $url" })"
    }

    $version = $manifest.version
    if(!$version) { abort "manifest doesn't specify a version" }
    if($version -match '[^\w\.\-_]') {
        abort "manifest version has unsupported character '$($matches[0])'"
    }

    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $(get-date)
        $check_hash = $false
    }

    echo "installing $app ($version)"

    $dir = ensure (versiondir $app $version $global)

    $fname = dl_urls $app $version $manifest $architecture $dir $use_cache $check_hash
    unpack_inno $fname $manifest $dir
    pre_install $manifest $architecture
    run_installer $fname $manifest $architecture $dir $global
    ensure_install_dir_not_in_path $dir $global
    create_shims $manifest $dir $global
    create_startmenu_shortcuts $manifest $dir $global
    if($global) { ensure_scoop_in_path $global } # can assume local scoop is in path
    env_add_path $manifest $dir $global
    env_set $manifest $dir $global
    # env_ensure_home $manifest $global (see comment for env_ensure_home)
    post_install $manifest $architecture

    # save info for uninstall
    save_installed_manifest $app $bucket $dir $url
    save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

    success "$app ($version) was installed successfully!"

    show_notes $manifest
}

function ensure_architecture($architecture_opt) {
    switch($architecture_opt) {
        '' { return default_architecture }
        { @('32bit','64bit') -contains $_ } { return $_ }
        default { abort "invalid architecture: '$architecture'"}
    }
}

function cache_path($app, $version, $url) {
    "$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')"
}

function appname_from_url($url) {
    (split-path $url -leaf) -replace '.json$', ''
}

function locate($app, $bucket) {
    $manifest, $url = $null, $null

    # check if app is a url
    if($app -match '^((ht)|f)tps?://') {
        $url = $app
        $app = appname_from_url $url
        $manifest = url_manifest $url
    } else {
        # check buckets
        $manifest, $bucket = find_manifest $app $bucket

        if(!$manifest) {
            # couldn't find app in buckets: check if it's a local path
            $path = $app
            if(!$path.endswith('.json')) { $path += '.json' }
            if(test-path $path) {
                $url = "$(resolve-path $path)"
                $app = appname_from_url $url
                $manifest, $bucket = url_manifest $url
            }
        }
    }

    return $app, $manifest, $bucket, $url
}

function dl_with_cache($app, $version, $url, $to, $cookies, $use_cache = $true) {
    $cached = fullpath (cache_path $app $version $url)
    if(!$use_cache) { warn "cache is being ignored" }

    if(!(test-path $cached) -or !$use_cache) {
        $null = ensure $cachedir
        write-host "downloading $url..." -nonewline
        do_dl $url "$cached.download" $cookies
        mv "$cached.download" $cached -force
        write-host "done"
    } else { write-host "loading $url from cache..."}
    cp $cached $to
}

function do_dl($url, $to, $cookies) {
    try {
        if([console]::isoutputredirected) {
            # can't set cursor position: just do simple download
            dl_simple $url $to $cookies
        } else {
            dl_progress $url $to $cookies
        }
    } catch {
        $e = $_.exception
        if($e.innerexception) { $e = $e.innerexception }
        abort $e.message
    }
}

# simple download (for when the console doesn't support setting cursor position)
function dl_simple($url, $to, $cookies) {
    $wc = new-object net.webclient
    $wc.headers.add('User-Agent', 'Scoop/1.0')
    $wc.headers.add('Cookie', (cookie_header $cookies))
    $wc.downloadfile($url, $to)
}

# download with filesize and progress indicator
function dl_progress($url, $to, $cookies) {
    $wreq = [net.webrequest]::create($url)
    $wreq.useragent = 'Scoop/1.0'
    $wreq.headers.add('Cookie', (cookie_header $cookies))

    $wres = $wreq.getresponse()
    try {
        $total = $wres.contentlength
        write-host "($(filesize $total)) " -nonewline

        $left = [console]::cursorleft
        $top = [console]::cursortop

        $s = $wres.getresponsestream()
        try {
            $fs = [io.file]::openwrite($to)
            try {
                $buffer = new-object byte[] 2048
                $totalread = 0

                while(($read = $s.read($buffer, 0, $buffer.length)) -gt 0) {
                    $fs.write($buffer, 0, $read)
                    $totalread += $read
                    $p = [math]::round($totalread / $total * 100, 0)
                    [console]::setcursorposition($left, $top)
                    write-host "$p%" -nonewline
                }
                [console]::setcursorposition($left, $top)
            } finally {
                $fs.close()
            }
        } finally {
            $s.close();
        }
    } finally {
        $wres.close()
    }
}

function dl_urls($app, $version, $manifest, $architecture, $dir, $use_cache = $true, $check_hash = $true) {
    # can be multiple urls: if there are, then msi or installer should go last,
    # so that $fname is set properly
    $urls = @(url $manifest $architecture)

    # can be multiple cookies: they will be used for all HTTP requests.
    $cookies = $manifest.cookie

    $fname = $null

    # extract_dir and extract_to in manifest are like queues: for each url that
    # needs to be extracted, will get the next dir from the queue
    $extract_dirs = @(extract_dir $manifest $architecture)
    $extract_tos = @(extract_to $manifest $architecture)
    $extracted = 0;

    foreach($url in $urls) {
        $fname = split-path $url -leaf

        dl_with_cache $app $version $url "$dir\$fname" $cookies $use_cache

        if($check_hash) {
            $ok, $err = check_hash "$dir\$fname" $url $manifest $architecture
            if(!$ok) {
                # rm cached
                $cached = cache_path $app $version $url
                if(test-path $cached) { rm -force $cached }
                abort $err
            }
        }

        $extract_dir = $extract_dirs[$extracted]
        $extract_to = $extract_tos[$extracted]

        # work out extraction method, if applicable
        $extract_fn = $null
        if($fname -match '\.zip$') { # unzip
            $extract_fn = 'unzip'
        } elseif($fname -match '\.msi$') {
            # check manifest doesn't use deprecated install method
            $msi = msi $manifest $architecture
            if(!$msi) {
                $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
                if ($useLessMsi -eq $true) {
                    $extract_fn, $extract_dir = lessmsi_config $extract_dir
                }
                else {
                    $extract_fn = 'extract_msi'
                }
            } else {
                warn "MSI install is deprecated. If you maintain this manifest, please refer to the manifest reference docs"
            }
        } elseif(file_requires_7zip $fname) { # 7zip
            if(!(7zip_installed)) {
                warn "aborting: you'll need to run 'scoop uninstall $app' to clean up"
                abort "7-zip is required. you can install it with 'scoop install 7zip'"
            }
            $extract_fn = 'extract_7zip'
        }

        if($extract_fn) {
            write-host "extracting..." -nonewline
            $null = mkdir "$dir\_scoop_extract"
            & $extract_fn "$dir\$fname" "$dir\_scoop_extract"
            if ($extract_to) {
                $null = mkdir "$dir\$extract_to" -force
            }
            # fails if zip contains long paths (e.g. atom.json)
            #cp "$dir\_scoop_extract\$extract_dir\*" "$dir\$extract_to" -r -force -ea stop
            movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

            if(test-path "$dir\_scoop_extract") { # might have been moved by movedir
                try {
                    rm -r -force "$dir\_scoop_extract" -ea stop
                } catch [system.io.pathtoolongexception] {
                    cmd /c "rmdir /s /q $dir\_scoop_extract"
                } catch [system.unauthorizedaccessexception] {
                    warn "couldn't remove $dir\_scoop_extract: unauthorized access"
                }
            }

            rm "$dir\$fname"
            write-host "done"

            $extracted++
        }
    }

    $fname # returns the last downloaded file
}

function lessmsi_config ($extract_dir) {
    $extract_fn = 'extract_lessmsi'
    if ($extract_dir) {
        $extract_dir = join-path SourceDir $extract_dir
    }
    else {
        $extract_dir = "SourceDir"
    }

    $extract_fn, $extract_dir
}

function cookie_header($cookies) {
    if(!$cookies) { return }

    $vals = $cookies.psobject.properties | % {
        "$($_.name)=$($_.value)"
    }

    [string]::join(';', $vals)
}

function is_in_dir($dir, $check) {
    $check = "$(fullpath $check)"
    $dir = "$(fullpath $dir)"
    $check -match "^$([regex]::escape("$dir"))(\\|`$)"
}

# hashes
function hash_for_url($manifest, $url, $arch) {
    $hashes = @(hash $manifest $arch) | ? { $_ -ne $null };

    if($hashes.length -eq 0) { return $null }

    $urls = @(url $manifest $arch)

    $index = [array]::indexof($urls, $url)
    if($index -eq -1) { abort "couldn't find hash in manifest for $url" }

    @($hashes)[$index]
}

# returns (ok, err)
function check_hash($file, $url, $manifest, $arch) {
    $hash = hash_for_url $manifest $url $arch
    if(!$hash) {
        warn "warning: no hash in manifest. sha256 is:`n$(compute_hash (fullpath $file) 'sha256')"
        return $true
    }

    write-host "checking hash..." -nonewline
    $type, $expected = $hash.split(':')
    if(!$expected) {
        # no type specified, assume sha256
        $type, $expected = 'sha256', $type
    }

    if(@('md5','sha1','sha256') -notcontains $type) {
        return $false, "hash type $type isn't supported"
    }

    $actual = compute_hash (fullpath $file) $type

    if($actual -ne $expected) {
        return $false, "hash check failed for $url. expected: $($expected), actual: $($actual)!"
    }
    write-host "ok"
    return $true
}

function compute_hash($file, $algname) {
    $alg = [system.security.cryptography.hashalgorithm]::create($algname)
    $fs = [system.io.file]::openread($file)
    try {
        $hexbytes = $alg.computehash($fs) | % { $_.tostring('x2') }
        [string]::join('', $hexbytes)
    } finally {
        $fs.dispose()
        $alg.dispose()
    }
}

function cmd_available($cmd) {
    try { gcm $cmd -ea stop } catch { return $false }
    $true
}

# for dealing with installers
function args($config, $dir, $global) {
    if($config) { return $config | % { (format $_ @{'dir'=$dir;'global'=$global}) } }
    @()
}

function run($exe, $arg, $msg, $continue_exit_codes) {
    if($msg) { write-host $msg -nonewline }
    try {
        #Allow null/no arguments to be passed
        $parameters = @{ }
        if ($arg)
        {
            $parameters.arg = $arg;
        }

        $proc = start-process $exe -wait -ea stop -passthru @parameters


        if($proc.exitcode -ne 0) {
            if($continue_exit_codes -and ($continue_exit_codes.containskey($proc.exitcode))) {
                warn $continue_exit_codes[$proc.exitcode]
                return $true
            }
            write-host "exit code was $($proc.exitcode)"; return $false
        }
    } catch {
        write-host -f darkred $_.exception.tostring()
        return $false
    }
    if($msg) { write-host "done" }
    return $true
}

function unpack_inno($fname, $manifest, $dir) {
    if(!$manifest.innosetup) { return }

    write-host "unpacking innosetup..." -nonewline
    innounp -x -d"$dir\_scoop_unpack" "$dir\$fname" > "$dir\innounp.log"
    if($lastexitcode -ne 0) {
        abort "failed to unpack innosetup file. see $dir\innounp.log"
    }

    gci "$dir\_scoop_unpack\{app}" -r | mv -dest "$dir" -force

    rmdir -r -force "$dir\_scoop_unpack"

    rm "$dir\$fname"
    write-host "done"
}

function run_installer($fname, $manifest, $architecture, $dir, $global) {
    # MSI or other installer
    $msi = msi $manifest $architecture
    $installer = installer $manifest $architecture

    if($msi) {
        install_msi $fname $dir $msi
    } elseif($installer) {
        install_prog $fname $dir $installer $global
    }
}

# deprecated (see also msi_installed)
function install_msi($fname, $dir, $msi) {
    $msifile = "$dir\$(coalesce $msi.file "$fname")"
    if(!(is_in_dir $dir $msifile)) {
        abort "error in manifest: MSI file $msifile is outside the app directory"
    }
    if(!($msi.code)) { abort "error in manifest: couldn't find MSI code"}
    if(msi_installed $msi.code) { abort "the MSI package is already installed on this system" }

    $logfile = "$dir\install.log"

    $arg = @("/i `"$msifile`"", '/norestart', "/lvp `"$logfile`"", "TARGETDIR=`"$dir`"",
        "INSTALLDIR=`"$dir`"") + @(args $msi.args $dir)

    if($msi.silent) { $arg += '/qn', 'ALLUSERS=2', 'MSIINSTALLPERUSER=1' }
    else { $arg += '/qb-!' }

    $continue_exit_codes = @{ 3010 = "a restart is required to complete installation" }

    $installed = run 'msiexec' $arg "running installer..." $continue_exit_codes
    if(!$installed) {
        abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
    }
    rm $logfile
    rm $msifile
}

function extract_msi($path, $to) {
    $logfile = "$(split-path $path)\msi.log"
    $ok = run 'msiexec' @('/a', "`"$path`"", '/qn', "TARGETDIR=`"$to`"", "/lwe `"$logfile`"")
    if(!$ok) { abort "failed to extract files from $path.`nlog file: $(friendly_path $logfile)" }
    if(test-path $logfile) { rm $logfile }
}

function extract_lessmsi($path, $to) {
    iex "lessmsi x `"$path`" `"$to\`""
}

# deprecated
# get-wmiobject win32_product is slow and checks integrity of each installed program,
# so this uses the [wmi] type accelerator instead
# http://blogs.technet.com/b/heyscriptingguy/archive/2011/12/14/use-powershell-to-find-and-uninstall-software.aspx
function msi_installed($code) {
    $path = "hklm:\software\microsoft\windows\currentversion\uninstall\$code"
    if(!(test-path $path)) { return $false }
    $key = gi $path
    $name = $key.getvalue('displayname')
    $version = $key.getvalue('displayversion')
    $classkey = "IdentifyingNumber=`"$code`",Name=`"$name`",Version=`"$version`""
    try { $wmi = [wmi]"Win32_Product.$classkey"; $true } catch { $false }
}

function install_prog($fname, $dir, $installer, $global) {
    $prog = "$dir\$(coalesce $installer.file "$fname")"
    if(!(is_in_dir $dir $prog)) {
        abort "error in manifest: installer $prog is outside the app directory"
    }
    $arg = @(args $installer.args $dir $global)

    if($prog.endswith('.ps1')) {
        & $prog @arg
    } else {
        $installed = run $prog $arg "running installer..."
        if(!$installed) {
            abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
        }

        #Don't remove installer if "keep" flag is set to true
        if (!($installer.keep -eq "true"))
        {
            rm $prog
        }
    }
}

function run_uninstaller($manifest, $architecture, $dir) {
    $msi = msi $manifest $architecture
    $uninstaller = uninstaller $manifest $architecture

    if($msi -or $uninstaller) {
        $exe = $null; $arg = $null; $continue_exit_codes = @{}

        if($msi) {
            $code = $msi.code
            $exe = "msiexec";
            $arg = @("/norestart", "/x $code")
            if($msi.silent) {
                $arg += '/qn', 'ALLUSERS=2', 'MSIINSTALLPERUSER=1'
            } else {
                $arg += '/qb-!'
            }

            $continue_exit_codes.1605 = 'not installed, skipping'
            $continue_exit_codes.3010 = 'restart required'
        } elseif($uninstaller) {
            $exe = "$dir\$($uninstaller.file)"
            $arg = args $uninstaller.args
            if(!(is_in_dir $dir $exe)) {
                warn "error in manifest: installer $exe is outside the app directory, skipping"
                $exe = $null;
            } elseif(!(test-path $exe)) {
                warn "uninstaller $exe is missing, skipping"
                $exe = $null;
            }
        }

        if($exe) {
            $uninstalled = run $exe $arg "running uninstaller..." $continue_exit_codes
            if(!$uninstalled) { abort "uninstallation aborted." }
        }
    }
}

# get target, name, arguments for shim
function shim_def($item) {
    if($item -is [array]) { return $item }
    return $item, (strip_ext (fname $item)), $null
}

function create_shims($manifest, $dir, $global) {
    $manifest.bin | ?{ $_ -ne $null } | % {
        $target, $name, $arg = shim_def $_
        echo "creating shim for $name"

        # check valid bin
        $bin = "$dir\$target"
        if(!(is_in_dir $dir $bin)) {
            abort "error in manifest: bin '$target' is outside the app directory"
        }
        if(!(test-path $bin)) { abort "can't shim $target`: file doesn't exist"}

        shim "$dir\$target" $global $name $arg
    }
}

function rm_shim($name, $shimdir) {
    $shim = "$shimdir\$name.ps1"

    if(!(test-path $shim)) { # handle no shim from failed install
        warn "shim for $name is missing, skipping"
    } else {
        echo "removing shim for $name"
        rm $shim
    }

    # other shim types might be present
    '.exe', '.shim', '.cmd' | % {
        if(test-path "$shimdir\$name$_") { rm "$shimdir\$name$_" }
    }
}

function rm_shims($manifest, $global) {
    $manifest.bin | ?{ $_ -ne $null } | % {
        $target, $name, $null = shim_def $_
        $shimdir = shimdir $global

        rm_shim $name $shimdir
    }
}

# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global) {
    $manifest.shortcuts | ?{ $_ -ne $null } | % {
        $target = $_.item(0)
        $name = $_.item(1)
        startmenu_shortcut "$dir\$target" $name
    }
}

function startmenu_shortcut($target, $shortcutName) {
    if(!(Test-Path $target)) {
        abort "Can't create the Startmenu shortcut for $(fname $target): couldn't find $target"
    }
    $scoop_startmenu_folder = "$env:USERPROFILE\Start Menu\Programs\Scoop Apps"
    if(!(Test-Path $scoop_startmenu_folder)) {
        New-Item $scoop_startmenu_folder -type Directory
    }
    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = "$target"
    $wsShell.Save()
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global) {
    $manifest.shortcuts | ?{ $_ -ne $null } | % {
        $name = $_.item(1)
        $shortcut = "$env:USERPROFILE\Start Menu\Programs\Scoop Apps\$name.lnk"
        if(Test-Path -Path $shortcut) {
             Remove-Item $shortcut
             echo "Removed shortcut $shortcut"
        }
    }
}

# to undo after installers add to path so that scoop manifest can keep track of this instead
function ensure_install_dir_not_in_path($dir, $global) {
    $path = (env 'path' $global)

    $fixed, $removed = find_dir_or_subdir $path "$dir"
    if($removed) {
        $removed | % { "installer added $(friendly_path $_) to path, removing"}
        env 'path' $global $fixed
    }

    if(!$global) {
        $fixed, $removed = find_dir_or_subdir (env 'path' $true) "$dir"
        if($removed) {
            $removed | % { warn "installer added $_ to system path: you might want to remove this manually (requires admin permission)"}
        }
    }
}

function find_dir_or_subdir($path, $dir) {
    $dir = $dir.trimend('\')
    $fixed = @()
    $removed = @()
    $path.split(';') | % {
        if($_) {
            if(($_ -eq $dir) -or ($_ -like "$dir\*")) { $removed += $_ }
            else { $fixed += $_ }
        }
    }
    return [string]::join(';', $fixed), $removed
}

function env_add_path($manifest, $dir, $global) {
    $manifest.env_add_path | ? { $_ } | % {
        $path_dir = "$dir\$($_)"
        if(!(is_in_dir $dir $path_dir)) {
            abort "error in manifest: env_add_path '$_' is outside the app directory"
        }
        add_first_in_path $path_dir $global
    }
}

function add_first_in_path($dir, $global) {
    $dir = fullpath $dir

    # future sessions
    $null, $currpath = strip_path (env 'path' $global) $dir
    env 'path' $global "$dir;$currpath"

    # this session
    $null, $env:path = strip_path $env:path $dir
    $env:path = "$dir;$env:path"
}

function env_rm_path($manifest, $dir, $global) {
    # remove from path
    $manifest.env_add_path | ? { $_ } | % {
        $path_dir = "$dir\$($_)"
        remove_from_path $path_dir $global
    }
}

function env_set($manifest, $dir, $global) {
    if($manifest.env_set) {
        $manifest.env_set | gm -member noteproperty | % {
            $name = $_.name;
            $val = format $manifest.env_set.$($_.name) @{ "dir" = $dir }
            env $name $global $val
            sc env:\$name $val
        }
    }
}
function env_rm($manifest, $global) {
    if($manifest.env_set) {
        $manifest.env_set | gm -member noteproperty | % {
            $name = $_.name
            env $name $global $null
            if(test-path env:\$name) { rm env:\$name }
        }
    }
}

# UNNECESSARY? Re-evaluate after 3-Jun-2017
# Supposedly some MSYS programs require %HOME% to be set, but I can't
# find any examples.
# Shims used to set %HOME% for the session, but this was removed.
# This function remains in case we need to support this functionality again
# (e.g. env_ensure_home in manifests). But if no problems arise by 3-Jun-2017,
# it's probably safe to delete this, and the call to it install_app
function env_ensure_home($manifest, $global) {
    if($manifest.env_ensure_home -eq $true) {
        if($global){
            if(!(env 'home' $true)) {
                env 'home' $true $env:ALLUSERSPROFILE
                $env:home = $env:ALLUSERSPROFILE # current session
            }
        } else {
            if(!(env 'home' $false)) {
                env 'home' $false $env:USERPROFILE
                $env:home = $env:USERPROFILE # current session
            }
        }
    }
}

function pre_install($manifest, $arch) {
    $pre_install = arch_specific 'pre_install' $manifest $arch
    if($pre_install) {
        echo "running pre-install script..."
        iex $pre_install
    }
}

function post_install($manifest, $arch) {
    $post_install = arch_specific 'post_install' $manifest $arch
    if($post_install) {
        echo "running post-install script..."
        iex $post_install
    }
}

function show_notes($manifest) {
    if($manifest.notes) {
        echo "Notes"
        echo "-----"
        echo (wraptext $manifest.notes)
    }
}

function all_installed($apps, $global) {
    $apps | ? {
        $app, $null = app $_
        installed $app $global
    }
}

function prune_installed($apps) {
    $installed = @(all_installed $apps $true) + @(all_installed $apps $false)
    $apps | ? { $installed -notcontains $_ }
}

# check whether the app failed to install
function failed($app, $global) {
    $ver = current_version $app $global
    if(!$ver) { return $false }
    $info = install_info $app $ver $global
    if(!$info) { return $true }
    return $false
}

function ensure_none_failed($apps, $global) {
    foreach($app in $apps) {
        if(failed $app $global) {
            abort "$app install failed previously. please uninstall it and try again."
        }
    }
}

# travelling directories have their contents moved from
# $from to $to when the app is updated.
# any files or directories that already exist in $to are skipped
function travel_dir($from, $to) {
    $skip_dirs = ls $to -dir | % { "`"$from\$_`"" }
    $skip_files = ls $to -file | % { "`"$from\$_`"" }

    robocopy $from $to /s /move /xd $skip_dirs /xf $skip_files > $null
}
