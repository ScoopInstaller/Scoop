function cache_path($app, $version, $url) {
	"$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')"
}

function appname_from_url($url) {
	(split-path $url -leaf) -replace '.json$', ''
}

function locate($app) {
	$manifest, $bucket, $url = $null, $null, $null

	# check if app is a url
	if($app -match '^((ht)|f)tps?://') {
		$url = $app
		$app = appname_from_url $url
		$manifest = url_manifest $url
	} else {
		# check buckets
		$manifest, $bucket = find_manifest $app

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

function dl_with_cache($app, $version, $url, $to) {
	$cached = fullpath (cache_path $app $version $url)
	if(!(test-path $cached)) {
		$null = ensure $cachedir
		write-host "downloading $url..." -nonewline
		dl_progress $url "$cached.download"
		mv "$cached.download" $cached
		write-host "done"
	} else { write-host "loading $url from cache..."}
	cp $cached $to
}

function dl_progress($url, $to) {
	if([console]::isoutputredirected) {
		# can't set cursor position: just do simple download
		(new-object net.webclient).downloadfile($url, $to)
		return
	}

	$left = [console]::cursorleft
	$top = [console]::cursortop

	$wc = new-object net.webclient
	register-objectevent $wc downloadprogresschanged progress | out-null
	register-objectevent $wc downloadfilecompleted complete | out-null
	try {
		$wc.downloadfileasync($url, $to)

		function is_complete {
			try { get-event complete -ea stop; $true } catch { $false }
		}

		$last_p = -1
		while(!(is_complete)) {
			$e = wait-event progress -timeout 1
			if(!$e) { continue } # avoid deadlock

			remove-event progress
			$p = $e.sourceeventargs.progresspercentage
			if($p -ne $last_p) {
				[console]::setcursorposition($left, $top)
				write-host "$p%" -nonewline
				$last_p = $p
			}
		}
		remove-event complete
	} finally {
		remove-event *
		unregister-event progress
		unregister-event complete
		
		$wc.cancelasync()
		$wc.dispose()
	}
	[console]::setcursorposition($left, $top)
}

function dl_urls($app, $version, $manifest, $architecture, $dir) {
	# can be multiple urls: if there are, then msi or installer should go last,
	# so that $fname is set properly
	$urls = @(url $manifest $architecture)

	$fname = $null

	# extract_dir and extract_to in manifest are like queues: for each url that
	# needs to be extracted, will get the next dir from the queue
	$extract_dirs = @(extract_dir $manifest $architecture)
	$extract_tos = @(extract_to $manifest $architecture)
	$extracted = 0;

	foreach($url in $urls) {
		$fname = split-path $url -leaf

		dl_with_cache $app $version $url "$dir\$fname"

		$ok, $err = check_hash "$dir\$fname" $url $manifest $architecture
		if(!$ok) {
			# rm cached
			$cached = cache_path $app $version $url
			if(test-path $cached) { rm -force $cached }
			abort $err
		}

		$extract_dir = $extract_dirs[$extracted]
		$extract_to = $extract_tos[$extracted]

		# extract
		if($fname -match '\.zip$') { # unzip
			write-host "extracting..." -nonewline
			# use tmp directory and copy so we can prevent 'folder merge' errors when multiple URLs
			$null = mkdir "$dir\_scoop_unzip"
			unzip "$dir\$fname" "$dir\_scoop_unzip" $extract_dir
			cp "$dir\_scoop_unzip\*" "$dir\$extract_to" -r -force
			rm -r -force "$dir\_scoop_unzip"
			rm "$dir\$fname"
			write-host "done"

			$extracted++
		} elseif(file_requires_7zip $fname) { # 7zip
			if(!(7zip_installed)) {
				warn "aborting: you'll need to run 'scoop uninstall $app' to clean up"
				abort "7-zip is required. you can install it with 'scoop install 7zip'"
			}
			$to = $dir

			if($extract_dir) {
				$to = "$dir\_scoop_extract"
			}

			extract_7zip "$dir\$fname" "$to\$extract_to"

			if($extract_dir) {
				gci "$to\$extract_to\$extract_dir" -r | mv -dest "$dir" -force
				rm -r -force "$to"
			}

			$extracted++
		}
	}

	$fname # returns the last downloaded file
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

function check_requirements($manifest, $architecture) {
	if(!(7zip_installed)) {
		if(requires_7zip $manifest $architecture) {
			abort "7zip is required to install this app. please run 'scoop install 7zip'"
		}
	}

	if($manifest.innosetup -and !(cmd_available 'innounp')) {
		abort "innounp is required to install this app. please run 'scoop install innounp'"
	} 
}

# for dealing with installers
function args($config, $dir) {
	if($config) { return $config | % { (format $_ @{'dir'=$dir}) } }
	@()
}

function run($exe, $arg, $msg, $continue_exit_codes) {
	write-host $msg -nonewline
	try {
		$proc = start-process $exe -wait -ea stop -passthru -arg $arg
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
	write-host "done"
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

function run_installer($fname, $manifest, $architecture, $dir) {
	# MSI or other installer
	$msi = msi $manifest $architecture
	$installer = installer $manifest $architecture

	if($msi) { 
		install_msi $fname $dir $msi
	} elseif($installer) {
		install_prog $fname $dir $installer
	}
}

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

function install_prog($fname, $dir, $installer) {
	$prog = "$dir\$(coalesce $installer.file "$fname")"
	if(!(is_in_dir $dir $prog)) {
		abort "error in manifest: installer $prog is outside the app directory"
	}
	$arg = @(args $installer.args $dir)

	if($prog.endswith('.ps1')) {
		& $prog @arg
	} else {
		$installed = run $prog $arg "running installer..."
		if(!$installed) {
			abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
		}
		rm $prog
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
			if(!$uninstalled) { abort "uninstallation aborted."	}
		}
	}
}

function create_shims($manifest, $dir, $global) {
	$manifest.bin | ?{ $_ -ne $null } | % {
		echo "creating shim for $_"

		# check valid bin
		$bin = "$dir\$_"
		if(!(is_in_dir $dir $bin)) {
			abort "error in manifest: bin '$_' is outside the app directory"
		}
		if(!(test-path $bin)) { abort "can't shim $_`: file doesn't exist"}

		shim "$dir\$_" $global
	}
}
function rm_shims($manifest, $global) {
	$manifest.bin | ?{ $_ -ne $null } | % {
		$shim = "$(shimdir $global)\$(strip_ext(fname $_)).ps1"

		$shim_cmd = "$(strip_ext $shim).cmd"

		if(!(test-path $shim)) { # handle no shim from failed install
			warn "shim for $_ is missing, skipping"
		} else {
			echo "removing shim for $_"
			rm $shim
		}

		if(test-path $shim_cmd) { rm $shim_cmd }
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

function post_install($manifest) {
	$manifest.post_install | ? {$_ } | % {
		echo "running post-install script..."
		iex $_
	}
}

function show_notes($manifest) {
	if($manifest.notes) {
		echo "Notes"
		echo "-----"
		echo (wraptext $manifest.notes)
	}
}