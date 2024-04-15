function nightly_version($quiet = $false) {
    if (!$quiet) {
        warn "This is a nightly version. Downloaded files won't be verified."
    }
    return "nightly-$(Get-Date -Format 'yyyyMMdd')"
}

function install_app($app, $architecture, $global, $suggested, $use_cache = $true, $check_hash = $true) {
    $app, $manifest, $bucket, $url = Get-Manifest $app

    if (!$manifest) {
        abort "Couldn't find manifest for '$app'$(if ($bucket) { " from '$bucket' bucket" } elseif ($url) { " at '$url'" })."
    }

    $version = $manifest.version
    if (!$version) { abort "Manifest doesn't specify a version." }
    if ($version -match '[^\w\.\-\+_]') {
        abort "Manifest version has unsupported character '$($matches[0])'."
    }

    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version
        $check_hash = $false
    }

    $architecture = Get-SupportedArchitecture $manifest $architecture
    if ($null -eq $architecture) {
        error "'$app' doesn't support current architecture!"
        return
    }

    if ((get_config SHOW_MANIFEST $false) -and ($MyInvocation.ScriptName -notlike '*scoop-update*')) {
        Write-Host "Manifest: $app.json"
        $style = get_config CAT_STYLE
        if ($style) {
            $manifest | ConvertToPrettyJson | bat --no-paging --style $style --language json
        } else {
            $manifest | ConvertToPrettyJson
        }
        $answer = Read-Host -Prompt 'Continue installation? [Y/n]'
        if (($answer -eq 'n') -or ($answer -eq 'N')) {
            return
        }
    }
    Write-Output "Installing '$app' ($version) [$architecture]$(if ($bucket) { " from '$bucket' bucket" } else { " from '$url'" })"

    $dir = ensure (versiondir $app $version $global)
    $original_dir = $dir # keep reference to real (not linked) directory
    $persist_dir = persistdir $app $global

    $fname = Invoke-ScoopDownload $app $version $manifest $bucket $architecture $dir $use_cache $check_hash
    Invoke-HookScript -HookType 'pre_install' -Manifest $manifest -Arch $architecture

    run_installer $fname $manifest $architecture $dir $global
    ensure_install_dir_not_in_path $dir $global
    $dir = link_current $dir
    create_shims $manifest $dir $global $architecture
    create_startmenu_shortcuts $manifest $dir $global $architecture
    install_psmodule $manifest $dir $global
    env_add_path $manifest $dir $global $architecture
    env_set $manifest $dir $global $architecture

    # persist data
    persist_data $manifest $original_dir $persist_dir
    persist_permission $manifest $global

    Invoke-HookScript -HookType 'post_install' -Manifest $manifest -Arch $architecture

    # save info for uninstall
    save_installed_manifest $app $bucket $dir $url
    save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

    if ($manifest.suggest) {
        $suggested[$app] = $manifest.suggest
    }

    success "'$app' ($version) was installed successfully!"

    show_notes $manifest $dir $original_dir $persist_dir
}

function Invoke-CachedDownload ($app, $version, $url, $to, $cookies = $null, $use_cache = $true) {
    $cached = cache_path $app $version $url

    if (!(Test-Path $cached) -or !$use_cache) {
        ensure $cachedir | Out-Null
        Start-Download $url "$cached.download" $cookies
        Move-Item "$cached.download" $cached -Force
    } else { Write-Host "Loading $(url_remote_filename $url) from cache" }

    if (!($null -eq $to)) {
        if ($use_cache) {
            Copy-Item $cached $to
        } else {
            Move-Item $cached $to -Force
        }
    }
}

function Start-Download ($url, $to, $cookies) {
    $progress = [console]::isoutputredirected -eq $false -and
    $host.name -ne 'Windows PowerShell ISE Host'

    try {
        $url = handle_special_urls $url
        Invoke-Download $url $to $cookies $progress
    } catch {
        $e = $_.exception
        if ($e.Response.StatusCode -eq 'Unauthorized') {
            warn 'Token might be misconfigured.'
        }
        if ($e.innerexception) { $e = $e.innerexception }
        throw $e
    }
}

function aria_exit_code($exitcode) {
    $codes = @{
        0  = 'All downloads were successful'
        1  = 'An unknown error occurred'
        2  = 'Timeout'
        3  = 'Resource was not found'
        4  = 'Aria2 saw the specified number of "resource not found" error. See --max-file-not-found option'
        5  = 'Download aborted because download speed was too slow. See --lowest-speed-limit option'
        6  = 'Network problem occurred.'
        7  = 'There were unfinished downloads. This error is only reported if all finished downloads were successful and there were unfinished downloads in a queue when aria2 exited by pressing Ctrl-C by an user or sending TERM or INT signal'
        8  = 'Remote server did not support resume when resume was required to complete download'
        9  = 'There was not enough disk space available'
        10 = 'Piece length was different from one in .aria2 control file. See --allow-piece-length-change option'
        11 = 'Aria2 was downloading same file at that moment'
        12 = 'Aria2 was downloading same info hash torrent at that moment'
        13 = 'File already existed. See --allow-overwrite option'
        14 = 'Renaming file failed. See --auto-file-renaming option'
        15 = 'Aria2 could not open existing file'
        16 = 'Aria2 could not create new file or truncate existing file'
        17 = 'File I/O error occurred'
        18 = 'Aria2 could not create directory'
        19 = 'Name resolution failed'
        20 = 'Aria2 could not parse Metalink document'
        21 = 'FTP command failed'
        22 = 'HTTP response header was bad or unexpected'
        23 = 'Too many redirects occurred'
        24 = 'HTTP authorization failed'
        25 = 'Aria2 could not parse bencoded file (usually ".torrent" file)'
        26 = '".torrent" file was corrupted or missing information that aria2 needed'
        27 = 'Magnet URI was bad'
        28 = 'Bad/unrecognized option was given or unexpected option argument was given'
        29 = 'The remote server was unable to handle the request due to a temporary overloading or maintenance'
        30 = 'Aria2 could not parse JSON-RPC request'
        31 = 'Reserved. Not used'
        32 = 'Checksum validation failed'
    }
    if ($null -eq $codes[$exitcode]) {
        return 'An unknown error occurred'
    }
    return $codes[$exitcode]
}

function get_filename_from_metalink($file) {
    $bytes = get_magic_bytes_pretty $file ''
    # check if file starts with '<?xml'
    if (!($bytes.StartsWith('3c3f786d6c'))) {
        return $null
    }

    # Add System.Xml for reading metalink files
    Add-Type -AssemblyName 'System.Xml'
    $xr = [System.Xml.XmlReader]::Create($file)
    $filename = $null
    try {
        $xr.ReadStartElement('metalink')
        if ($xr.ReadToFollowing('file') -and $xr.MoveToFirstAttribute()) {
            $filename = $xr.Value
        }
    } catch [System.Xml.XmlException] {
        return $null
    } finally {
        $xr.Close()
    }

    return $filename
}

function Invoke-CachedAria2Download ($app, $version, $manifest, $architecture, $dir, $cookies = $null, $use_cache = $true, $check_hash = $true) {
    $data = @{}
    $urls = @(script:url $manifest $architecture)

    # aria2 input file
    $urlstxt = Join-Path $cachedir "$app.txt"
    $urlstxt_content = ''
    $download_finished = $true

    # aria2 options
    $options = @(
        "--input-file='$urlstxt'"
        "--user-agent='$(Get-UserAgent)'"
        '--allow-overwrite=true'
        '--auto-file-renaming=false'
        "--retry-wait=$(get_config 'aria2-retry-wait' 2)"
        "--split=$(get_config 'aria2-split' 5)"
        "--max-connection-per-server=$(get_config 'aria2-max-connection-per-server' 5)"
        "--min-split-size=$(get_config 'aria2-min-split-size' '5M')"
        '--console-log-level=warn'
        '--enable-color=false'
        '--no-conf=true'
        '--follow-metalink=true'
        '--metalink-preferred-protocol=https'
        '--min-tls-version=TLSv1.2'
        "--stop-with-process=$PID"
        '--continue'
        '--summary-interval=0'
        '--auto-save-interval=1'
    )

    if ($cookies) {
        $options += "--header='Cookie: $(cookie_header $cookies)'"
    }

    $proxy = get_config PROXY
    if ($proxy -ne 'none') {
        if ([Net.Webrequest]::DefaultWebProxy.Address) {
            $options += "--all-proxy='$([Net.Webrequest]::DefaultWebProxy.Address.Authority)'"
        }
        if ([Net.Webrequest]::DefaultWebProxy.Credentials.UserName) {
            $options += "--all-proxy-user='$([Net.Webrequest]::DefaultWebProxy.Credentials.UserName)'"
        }
        if ([Net.Webrequest]::DefaultWebProxy.Credentials.Password) {
            $options += "--all-proxy-passwd='$([Net.Webrequest]::DefaultWebProxy.Credentials.Password)'"
        }
    }

    $more_options = get_config 'aria2-options'
    if ($more_options) {
        $options += $more_options
    }

    foreach ($url in $urls) {
        $data.$url = @{
            'target'    = "$dir\$(url_filename $url)"
            'cachename' = fname (cache_path $app $version $url)
            'source'    = cache_path $app $version $url
        }

        if ((Test-Path $data.$url.source) -and -not((Test-Path "$($data.$url.source).aria2") -or (Test-Path $urlstxt)) -and $use_cache) {
            Write-Host 'Loading ' -NoNewline
            Write-Host $(url_remote_filename $url) -f Cyan -NoNewline
            Write-Host ' from cache.'
        } else {
            $download_finished = $false
            # create aria2 input file content
            try {
                $try_url = handle_special_urls $url
            } catch {
                if ($_.Exception.Response.StatusCode -eq 'Unauthorized') {
                    warn 'Token might be misconfigured.'
                }
            }
            $urlstxt_content += "$try_url`n"
            if (!$url.Contains('sourceforge.net')) {
                $urlstxt_content += "    referer=$(strip_filename $url)`n"
            }
            $urlstxt_content += "    dir=$cachedir`n"
            $urlstxt_content += "    out=$($data.$url.cachename)`n"
        }
    }

    if (-not($download_finished)) {
        # write aria2 input file
        if ($urlstxt_content -ne '') {
            ensure $cachedir | Out-Null
            # Write aria2 input-file with UTF8NoBOM encoding
            $urlstxt_content | Out-UTF8File -FilePath $urlstxt
        }

        # build aria2 command
        $aria2 = "& '$(Get-HelperPath -Helper Aria2)' $($options -join ' ')"

        # handle aria2 console output
        Write-Host 'Starting download with aria2 ...'

        # Set console output encoding to UTF8 for non-ASCII characters printing
        $oriConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding

        Invoke-Command ([scriptblock]::Create($aria2)) | ForEach-Object {
            # Skip blank lines
            if ([String]::IsNullOrWhiteSpace($_)) { return }

            # Prevent potential overlaping of text when one line is shorter
            $len = $Host.UI.RawUI.WindowSize.Width - $_.Length - 20
            $blank = if ($len -gt 0) { ' ' * $len } else { '' }
            $color = 'Gray'

            if ($_.StartsWith('(OK):')) {
                $noNewLine = $true
                $color = 'Green'
            } elseif ($_.StartsWith('[') -and $_.EndsWith(']')) {
                $noNewLine = $true
                $color = 'Cyan'
            } elseif ($_.StartsWith('Download Results:')) {
                $noNewLine = $false
            }

            Write-Host "`rDownload: $_$blank" -ForegroundColor $color -NoNewline:$noNewLine
        }
        Write-Host ''

        if ($lastexitcode -gt 0) {
            error "Download failed! (Error $lastexitcode) $(aria_exit_code $lastexitcode)"
            error $urlstxt_content
            error $aria2
            abort $(new_issue_msg $app $bucket 'download via aria2 failed')
        }

        # remove aria2 input file when done
        if (Test-Path $urlstxt, "$($data.$url.source).aria2*") {
            Remove-Item $urlstxt -Force -ErrorAction SilentlyContinue
            Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
        }

        # Revert console encoding
        [Console]::OutputEncoding = $oriConsoleEncoding
    }

    foreach ($url in $urls) {

        $metalink_filename = get_filename_from_metalink $data.$url.source
        if ($metalink_filename) {
            Remove-Item $data.$url.source -Force
            Rename-Item -Force (Join-Path -Path $cachedir -ChildPath $metalink_filename) $data.$url.source
        }

        # run hash checks
        if ($check_hash) {
            $manifest_hash = hash_for_url $manifest $url $architecture
            $ok, $err = check_hash $data.$url.source $manifest_hash $(show_app $app $bucket)
            if (!$ok) {
                error $err
                if (Test-Path $data.$url.source) {
                    # rm cached file
                    Remove-Item $data.$url.source -Force -ErrorAction SilentlyContinue
                    Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
                }
                if ($url.Contains('sourceforge.net')) {
                    Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                }
                abort $(new_issue_msg $app $bucket 'hash check failed')
            }
        }

        # copy or move file to target location
        if (!(Test-Path $data.$url.source) ) {
            abort $(new_issue_msg $app $bucket 'cached file not found')
        }

        if (!($dir -eq $cachedir)) {
            if ($use_cache) {
                Copy-Item $data.$url.source $data.$url.target
            } else {
                Move-Item $data.$url.source $data.$url.target -Force
            }
        }
    }
}

# download with filesize and progress indicator
function Invoke-Download ($url, $to, $cookies, $progress) {
    $reqUrl = ($url -split '#')[0]
    $wreq = [Net.WebRequest]::Create($reqUrl)
    if ($wreq -is [Net.HttpWebRequest]) {
        $wreq.UserAgent = Get-UserAgent
        if (-not ($url -match 'sourceforge\.net' -or $url -match 'portableapps\.com')) {
            $wreq.Referer = strip_filename $url
        }
        if ($url -match 'api\.github\.com/repos') {
            $wreq.Accept = 'application/octet-stream'
            $wreq.Headers['Authorization'] = "Bearer $(Get-GitHubToken)"
            $wreq.Headers['X-GitHub-Api-Version'] = '2022-11-28'
        }
        if ($cookies) {
            $wreq.Headers.Add('Cookie', (cookie_header $cookies))
        }

        get_config PRIVATE_HOSTS | Where-Object { $_ -ne $null -and $url -match $_.match } | ForEach-Object {
            (ConvertFrom-StringData -StringData $_.Headers).GetEnumerator() | ForEach-Object {
                $wreq.Headers[$_.Key] = $_.Value
            }
        }
    }

    try {
        $wres = $wreq.GetResponse()
    } catch [System.Net.WebException] {
        $exc = $_.Exception
        $handledCodes = @(
            [System.Net.HttpStatusCode]::MovedPermanently, # HTTP 301
            [System.Net.HttpStatusCode]::Found, # HTTP 302
            [System.Net.HttpStatusCode]::SeeOther, # HTTP 303
            [System.Net.HttpStatusCode]::TemporaryRedirect  # HTTP 307
        )

        # Only handle redirection codes
        $redirectRes = $exc.Response
        if ($handledCodes -notcontains $redirectRes.StatusCode) {
            throw $exc
        }

        # Get the new location of the file
        if ((-not $redirectRes.Headers) -or ($redirectRes.Headers -notcontains 'Location')) {
            throw $exc
        }

        $newUrl = $redirectRes.Headers['Location']
        info "Following redirect to $newUrl..."

        # Handle manual file rename
        if ($url -like '*#/*') {
            $null, $postfix = $url -split '#/'
            $newUrl = "$newUrl#/$postfix"
        }

        Invoke-Download $newUrl $to $cookies $progress
        return
    }

    $total = $wres.ContentLength
    if ($total -eq -1 -and $wreq -is [net.ftpwebrequest]) {
        $total = ftp_file_size($url)
    }

    if ($progress -and ($total -gt 0)) {
        [console]::CursorVisible = $false
        function Trace-DownloadProgress ($read) {
            Write-DownloadProgress $read $total $url
        }
    } else {
        Write-Host "Downloading $url ($(filesize $total))..."
        function Trace-DownloadProgress {
            #no op
        }
    }

    try {
        $s = $wres.getresponsestream()
        $fs = [io.file]::openwrite($to)
        $buffer = New-Object byte[] 2048
        $totalRead = 0
        $sw = [diagnostics.stopwatch]::StartNew()

        Trace-DownloadProgress $totalRead
        while (($read = $s.read($buffer, 0, $buffer.length)) -gt 0) {
            $fs.write($buffer, 0, $read)
            $totalRead += $read
            if ($sw.elapsedmilliseconds -gt 100) {
                $sw.restart()
                Trace-DownloadProgress $totalRead
            }
        }
        $sw.stop()
        Trace-DownloadProgress $totalRead
    } finally {
        if ($progress) {
            [console]::CursorVisible = $true
            Write-Host
        }
        if ($fs) {
            $fs.close()
        }
        if ($s) {
            $s.close()
        }
        $wres.close()
    }
}

function Format-DownloadProgress ($url, $read, $total, $console) {
    $filename = url_remote_filename $url

    # calculate current percentage done
    $p = [math]::Round($read / $total * 100, 0)

    # pre-generate LHS and RHS of progress string
    # so we know how much space we have
    $left = "$filename ($(filesize $total))"
    $right = [string]::Format('{0,3}%', $p)

    # calculate remaining width for progress bar
    $midwidth = $console.BufferSize.Width - ($left.Length + $right.Length + 8)

    # calculate how many characters are completed
    $completed = [math]::Abs([math]::Round(($p / 100) * $midwidth, 0) - 1)

    # generate dashes to symbolise completed
    if ($completed -gt 1) {
        $dashes = [string]::Join('', ((1..$completed) | ForEach-Object { '=' }))
    }

    # this is why we calculate $completed - 1 above
    $dashes += switch ($p) {
        100 { '=' }
        default { '>' }
    }

    # the remaining characters are filled with spaces
    $spaces = switch ($dashes.Length) {
        $midwidth { [string]::Empty }
        default {
            [string]::Join('', ((1..($midwidth - $dashes.Length)) | ForEach-Object { ' ' }))
        }
    }

    "$left [$dashes$spaces] $right"
}

function Write-DownloadProgress ($read, $total, $url) {
    $console = $host.UI.RawUI
    $left = $console.CursorPosition.X
    $top = $console.CursorPosition.Y
    $width = $console.BufferSize.Width

    if ($read -eq 0) {
        $maxOutputLength = $(Format-DownloadProgress $url 100 $total $console).length
        if (($left + $maxOutputLength) -gt $width) {
            # not enough room to print progress on this line
            # print on new line
            Write-Host
            $left = 0
            $top = $top + 1
            if ($top -gt $console.CursorPosition.Y) { $top = $console.CursorPosition.Y }
        }
    }

    Write-Host $(Format-DownloadProgress $url $read $total $console) -NoNewline
    [console]::SetCursorPosition($left, $top)
}

function Invoke-ScoopDownload ($app, $version, $manifest, $bucket, $architecture, $dir, $use_cache = $true, $check_hash = $true) {
    # we only want to show this warning once
    if (!$use_cache) { warn 'Cache is being ignored.' }

    # can be multiple urls: if there are, then installer should go last,
    # so that $fname is set properly
    $urls = @(script:url $manifest $architecture)

    # can be multiple cookies: they will be used for all HTTP requests.
    $cookies = $manifest.cookie

    $fname = $null

    # extract_dir and extract_to in manifest are like queues: for each url that
    # needs to be extracted, will get the next dir from the queue
    $extract_dirs = @(extract_dir $manifest $architecture)
    $extract_tos = @(extract_to $manifest $architecture)
    $extracted = 0

    # download first
    if (Test-Aria2Enabled) {
        Invoke-CachedAria2Download $app $version $manifest $architecture $dir $cookies $use_cache $check_hash
    } else {
        foreach ($url in $urls) {
            $fname = url_filename $url

            try {
                Invoke-CachedDownload $app $version $url "$dir\$fname" $cookies $use_cache
            } catch {
                Write-Host -f darkred $_
                abort "URL $url is not valid"
            }

            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $ok, $err = check_hash "$dir\$fname" $manifest_hash $(show_app $app $bucket)
                if (!$ok) {
                    error $err
                    $cached = cache_path $app $version $url
                    if (Test-Path $cached) {
                        # rm cached file
                        Remove-Item -Force $cached
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket 'hash check failed')
                }
            }
        }
    }

    foreach ($url in $urls) {
        $fname = url_filename $url

        $extract_dir = $extract_dirs[$extracted]
        $extract_to = $extract_tos[$extracted]

        # work out extraction method, if applicable
        $extract_fn = $null
        if ($manifest.innosetup) {
            $extract_fn = 'Expand-InnoArchive'
        } elseif ($fname -match '\.zip$') {
            # Use 7zip when available (more fast)
            if (((get_config USE_EXTERNAL_7ZIP) -and (Test-CommandAvailable 7z)) -or (Test-HelperInstalled -Helper 7zip)) {
                $extract_fn = 'Expand-7zipArchive'
            } else {
                $extract_fn = 'Expand-ZipArchive'
            }
        } elseif ($fname -match '\.msi$') {
            $extract_fn = 'Expand-MsiArchive'
        } elseif (Test-ZstdRequirement -Uri $fname) {
            # Zstd first
            $extract_fn = 'Expand-ZstdArchive'
        } elseif (Test-7zipRequirement -Uri $fname) {
            # 7zip
            $extract_fn = 'Expand-7zipArchive'
        }

        if ($extract_fn) {
            Write-Host 'Extracting ' -NoNewline
            Write-Host $fname -f Cyan -NoNewline
            Write-Host ' ... ' -NoNewline
            & $extract_fn -Path "$dir\$fname" -DestinationPath "$dir\$extract_to" -ExtractDir $extract_dir -Removal
            Write-Host 'done.' -f Green
            $extracted++
        }
    }

    $fname # returns the last downloaded file
}

function cookie_header($cookies) {
    if (!$cookies) { return }

    $vals = $cookies.psobject.properties | ForEach-Object {
        "$($_.name)=$($_.value)"
    }

    [string]::join(';', $vals)
}

function is_in_dir($dir, $check) {
    $check -match "^$([regex]::Escape("$dir"))([/\\]|$)"
}

function ftp_file_size($url) {
    $request = [net.ftpwebrequest]::create($url)
    $request.method = [net.webrequestmethods+ftp]::getfilesize
    $request.getresponse().contentlength
}

# hashes
function hash_for_url($manifest, $url, $arch) {
    $hashes = @(hash $manifest $arch) | Where-Object { $_ -ne $null }

    if ($hashes.length -eq 0) { return $null }

    $urls = @(script:url $manifest $arch)

    $index = [array]::indexof($urls, $url)
    if ($index -eq -1) { abort "Couldn't find hash in manifest for '$url'." }

    @($hashes)[$index]
}

# returns (ok, err)
function check_hash($file, $hash, $app_name) {
    if (!$hash) {
        warn "Warning: No hash in manifest. SHA256 for '$(fname $file)' is:`n    $((Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower())"
        return $true, $null
    }

    Write-Host 'Checking hash of ' -NoNewline
    Write-Host $(url_remote_filename $url) -f Cyan -NoNewline
    Write-Host ' ... ' -NoNewline
    $algorithm, $expected = get_hash $hash
    if ($null -eq $algorithm) {
        return $false, "Hash type '$algorithm' isn't supported."
    }

    $actual = (Get-FileHash -Path $file -Algorithm $algorithm).Hash.ToLower()
    $expected = $expected.ToLower()

    if ($actual -ne $expected) {
        $msg = "Hash check failed!`n"
        $msg += "App:         $app_name`n"
        $msg += "URL:         $url`n"
        if (Test-Path $file) {
            $msg += "First bytes: $((get_magic_bytes_pretty $file ' ').ToUpper())`n"
        }
        if ($expected -or $actual) {
            $msg += "Expected:    $expected`n"
            $msg += "Actual:      $actual"
        }
        return $false, $msg
    }
    Write-Host 'ok.' -f Green
    return $true, $null
}

# for dealing with installers
function args($config, $dir, $global) {
    if ($config) { return $config | ForEach-Object { (format $_ @{'dir' = $dir; 'global' = $global }) } }
    @()
}

function run_installer($fname, $manifest, $architecture, $dir, $global) {
    $installer = installer $manifest $architecture
    if ($installer.script) {
        Write-Output 'Running installer script...'
        Invoke-Command ([scriptblock]::Create($installer.script -join "`r`n"))
        return
    }
    if ($installer) {
        $prog = "$dir\$(coalesce $installer.file "$fname")"
        if (!(is_in_dir $dir $prog)) {
            abort "Error in manifest: Installer $prog is outside the app directory."
        }
        $arg = @(args $installer.args $dir $global)
        if ($prog.endswith('.ps1')) {
            & $prog @arg
        } else {
            $installed = Invoke-ExternalCommand $prog $arg -Activity 'Running installer...'
            if (!$installed) {
                abort "Installation aborted. You might need to run 'scoop uninstall $app' before trying again."
            }
            # Don't remove installer if "keep" flag is set to true
            if (!($installer.keep -eq 'true')) {
                Remove-Item $prog
            }
        }
    }
}

function run_uninstaller($manifest, $architecture, $dir) {
    $uninstaller = uninstaller $manifest $architecture
    $version = $manifest.version
    if ($uninstaller.script) {
        Write-Output 'Running uninstaller script...'
        Invoke-Command ([scriptblock]::Create($uninstaller.script -join "`r`n"))
        return
    }

    if ($uninstaller.file) {
        $prog = "$dir\$($uninstaller.file)"
        $arg = args $uninstaller.args
        if (!(is_in_dir $dir $prog)) {
            warn "Error in manifest: Installer $prog is outside the app directory, skipping."
            $prog = $null
        } elseif (!(Test-Path $prog)) {
            warn "Uninstaller $prog is missing, skipping."
            $prog = $null
        }

        if ($prog) {
            if ($prog.endswith('.ps1')) {
                & $prog @arg
            } else {
                $uninstalled = Invoke-ExternalCommand $prog $arg -Activity 'Running uninstaller...'
                if (!$uninstalled) {
                    abort 'Uninstallation aborted.'
                }
            }
        }
    }
}

# get target, name, arguments for shim
function shim_def($item) {
    if ($item -is [array]) { return $item }
    return $item, (strip_ext (fname $item)), $null
}

function create_shims($manifest, $dir, $global, $arch) {
    $shims = @(arch_specific 'bin' $manifest $arch)
    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $arg = shim_def $_
        Write-Output "Creating shim for '$name'."

        if (Test-Path "$dir\$target" -PathType leaf) {
            $bin = "$dir\$target"
        } elseif (Test-Path $target -PathType leaf) {
            $bin = $target
        } else {
            $bin = (Get-Command $target).Source
        }
        if (!$bin) { abort "Can't shim '$target': File doesn't exist." }

        shim $bin $global $name (substitute $arg @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
    }
}

function rm_shim($name, $shimdir, $app) {
    '', '.shim', '.cmd', '.ps1' | ForEach-Object {
        $shimPath = "$shimdir\$name$_"
        $altShimPath = "$shimPath.$app"
        if ($app -and (Test-Path -Path $altShimPath -PathType Leaf)) {
            Write-Output "Removing shim '$name$_.$app'."
            Remove-Item $altShimPath
        } elseif (Test-Path -Path $shimPath -PathType Leaf) {
            Write-Output "Removing shim '$name$_'."
            Remove-Item $shimPath
            $oldShims = Get-Item -Path "$shimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
            if ($null -eq $oldShims) {
                if ($_ -eq '.shim') {
                    Write-Output "Removing shim '$name.exe'."
                    Remove-Item -Path "$shimdir\$name.exe"
                }
            } else {
                (@($oldShims) | Sort-Object -Property LastWriteTimeUtc)[-1] | Rename-Item -NewName { $_.Name -replace '\.[^.]*$', '' }
            }
        }
    }
}

function rm_shims($app, $manifest, $global, $arch) {
    $shims = @(arch_specific 'bin' $manifest $arch)

    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $null = shim_def $_
        $shimdir = shimdir $global

        rm_shim $name $shimdir $app
    }
}

# Creates or updates the directory junction for [app]/current,
# pointing to the specified version directory for the app.
#
# Returns the 'current' junction directory if in use, otherwise
# the version directory.
function link_current($versiondir) {
    if (get_config NO_JUNCTION) { return $versiondir.ToString() }

    $currentdir = "$(Split-Path $versiondir)\current"

    Write-Host "Linking $(friendly_path $currentdir) => $(friendly_path $versiondir)"

    if ($currentdir -eq $versiondir) {
        abort "Error: Version 'current' is not allowed!"
    }

    if (Test-Path $currentdir) {
        # remove the junction
        attrib -R /L $currentdir
        Remove-Item $currentdir -Recurse -Force -ErrorAction Stop
    }

    New-DirectoryJunction $currentdir $versiondir | Out-Null
    attrib $currentdir +R /L
    return $currentdir
}

# Removes the directory junction for [app]/current which
# points to the current version directory for the app.
#
# Returns the 'current' junction directory (if it exists),
# otherwise the normal version directory.
function unlink_current($versiondir) {
    if (get_config NO_JUNCTION) { return $versiondir.ToString() }
    $currentdir = "$(Split-Path $versiondir)\current"

    if (Test-Path $currentdir) {
        Write-Host "Unlinking $(friendly_path $currentdir)"

        # remove read-only attribute on link
        attrib $currentdir -R /L

        # remove the junction
        Remove-Item $currentdir -Recurse -Force -ErrorAction Stop
        return $currentdir
    }
    return $versiondir
}

# to undo after installers add to path so that scoop manifest can keep track of this instead
function ensure_install_dir_not_in_path($dir, $global) {
    $path = (Get-EnvVar -Name 'PATH' -Global:$global)

    $fixed, $removed = find_dir_or_subdir $path "$dir"
    if ($removed) {
        $removed | ForEach-Object { "Installer added '$(friendly_path $_)' to path. Removing." }
        Set-EnvVar -Name 'PATH' -Value $fixed -Global:$global
    }

    if (!$global) {
        $fixed, $removed = find_dir_or_subdir (Get-EnvVar -Name 'PATH' -Global) "$dir"
        if ($removed) {
            $removed | ForEach-Object { warn "Installer added '$_' to system path. You might want to remove this manually (requires admin permission)." }
        }
    }
}

function find_dir_or_subdir($path, $dir) {
    $dir = $dir.trimend('\')
    $fixed = @()
    $removed = @()
    $path.split(';') | ForEach-Object {
        if ($_) {
            if (($_ -eq $dir) -or ($_ -like "$dir\*")) { $removed += $_ }
            else { $fixed += $_ }
        }
    }
    return [string]::join(';', $fixed), $removed
}

function env_add_path($manifest, $dir, $global, $arch) {
    $env_add_path = arch_specific 'env_add_path' $manifest $arch
    $dir = $dir.TrimEnd('\')
    if ($env_add_path) {
        if (get_config USE_ISOLATED_PATH) {
            Add-Path -Path ('%' + $scoopPathEnvVar + '%') -Global:$global
        }
        $path = $env_add_path.Where({ $_ }).ForEach({ Join-Path $dir $_ | Get-AbsolutePath }).Where({ is_in_dir $dir $_ })
        Add-Path -Path $path -TargetEnvVar $scoopPathEnvVar -Global:$global -Force
    }
}

function env_rm_path($manifest, $dir, $global, $arch) {
    $env_add_path = arch_specific 'env_add_path' $manifest $arch
    $dir = $dir.TrimEnd('\')
    if ($env_add_path) {
        $path = $env_add_path.Where({ $_ }).ForEach({ Join-Path $dir $_ | Get-AbsolutePath }).Where({ is_in_dir $dir $_ })
        Remove-Path -Path $path -Global:$global # TODO: Remove after forced isolating Scoop path
        Remove-Path -Path $path -TargetEnvVar $scoopPathEnvVar -Global:$global
    }
}

function env_set($manifest, $dir, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -Member NoteProperty | ForEach-Object {
            $name = $_.name
            $val = format $env_set.$($_.name) @{ 'dir' = $dir }
            Set-EnvVar -Name $name -Value $val -Global:$global
            Set-Content env:\$name $val
        }
    }
}
function env_rm($manifest, $global, $arch) {
    $env_set = arch_specific 'env_set' $manifest $arch
    if ($env_set) {
        $env_set | Get-Member -Member NoteProperty | ForEach-Object {
            $name = $_.name
            Set-EnvVar -Name $name -Value $null -Global:$global
            if (Test-Path env:\$name) { Remove-Item env:\$name }
        }
    }
}

function Invoke-HookScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('pre_install', 'post_install',
            'pre_uninstall', 'post_uninstall')]
        [String] $HookType,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Manifest,
        [Parameter(Mandatory = $true)]
        [ValidateSet('32bit', '64bit', 'arm64')]
        [String] $Arch
    )

    $script = arch_specific $HookType $Manifest $Arch
    if ($script) {
        Write-Output "Running $HookType script..."
        Invoke-Command ([scriptblock]::Create($script -join "`r`n"))
    }
}

function show_notes($manifest, $dir, $original_dir, $persist_dir) {
    if ($manifest.notes) {
        Write-Output 'Notes'
        Write-Output '-----'
        Write-Output (wraptext (substitute $manifest.notes @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir }))
    }
}

function all_installed($apps, $global) {
    $apps | Where-Object {
        $app, $null, $null = parse_app $_
        installed $app $global
    }
}

# returns (uninstalled, installed)
function prune_installed($apps, $global) {
    $installed = @(all_installed $apps $global)

    $uninstalled = $apps | Where-Object { $installed -notcontains $_ }

    return @($uninstalled), @($installed)
}

function ensure_none_failed($apps) {
    foreach ($app in $apps) {
        $app = ($app -split '/|\\')[-1] -replace '\.json$', ''
        foreach ($global in $true, $false) {
            if ($global) {
                $instArgs = @('--global')
            } else {
                $instArgs = @()
            }
            if (failed $app $global) {
                if (installed $app $global) {
                    info "Repair previous failed installation of $app."
                    & "$PSScriptRoot\..\libexec\scoop-reset.ps1" $app @instArgs
                } else {
                    warn "Purging previous failed installation of $app."
                    & "$PSScriptRoot\..\libexec\scoop-uninstall.ps1" $app @instArgs
                }
            }
        }
    }
}

function show_suggestions($suggested) {
    $installed_apps = (installed_apps $true) + (installed_apps $false)

    foreach ($app in $suggested.keys) {
        $features = $suggested[$app] | Get-Member -type noteproperty | ForEach-Object { $_.name }
        foreach ($feature in $features) {
            $feature_suggestions = $suggested[$app].$feature

            $fulfilled = $false
            foreach ($suggestion in $feature_suggestions) {
                $suggested_app, $bucket, $null = parse_app $suggestion

                if ($installed_apps -contains $suggested_app) {
                    $fulfilled = $true
                    break
                }
            }

            if (!$fulfilled) {
                Write-Host "'$app' suggests installing '$([string]::join("' or '", $feature_suggestions))'."
            }
        }
    }
}

# Persistent data
function persist_def($persist) {
    if ($persist -is [Array]) {
        $source = $persist[0]
        $target = $persist[1]
    } else {
        $source = $persist
        $target = $null
    }

    if (!$target) {
        $target = $source
    }

    return $source, $target
}

function persist_data($manifest, $original_dir, $persist_dir) {
    $persist = $manifest.persist
    if ($persist) {
        $persist_dir = ensure $persist_dir

        if ($persist -is [String]) {
            $persist = @($persist)
        }

        $persist | ForEach-Object {
            $source, $target = persist_def $_

            Write-Host "Persisting $source"

            $source = $source.TrimEnd('/').TrimEnd('\\')

            $source = "$dir\$source"
            $target = "$persist_dir\$target"

            # if we have had persist data in the store, just create link and go
            if (Test-Path $target) {
                # if there is also a source data, rename it (to keep a original backup)
                if (Test-Path $source) {
                    Move-Item -Force $source "$source.original"
                }
                # we don't have persist data in the store, move the source to target, then create link
            } elseif (Test-Path $source) {
                # ensure target parent folder exist
                ensure (Split-Path -Path $target) | Out-Null
                Move-Item $source $target
                # we don't have neither source nor target data! we need to create an empty target,
                # but we can't make a judgement that the data should be a file or directory...
                # so we create a directory by default. to avoid this, use pre_install
                # to create the source file before persisting (DON'T use post_install)
            } else {
                $target = New-Object System.IO.DirectoryInfo($target)
                ensure $target | Out-Null
            }

            # create link
            if (is_directory $target) {
                # target is a directory, create junction
                New-DirectoryJunction $source $target | Out-Null
                attrib $source +R /L
            } else {
                # target is a file, create hard link
                New-Item -Path $source -ItemType HardLink -Value $target | Out-Null
            }
        }
    }
}

function unlink_persist_data($manifest, $dir) {
    $persist = $manifest.persist
    # unlink all junction / hard link in the directory
    if ($persist) {
        @($persist) | ForEach-Object {
            $source, $null = persist_def $_
            $source = Get-Item "$dir\$source" -ErrorAction SilentlyContinue
            if ($source.LinkType) {
                $source_path = $source.FullName
                # directory (junction)
                if ($source -is [System.IO.DirectoryInfo]) {
                    # remove read-only attribute on the link
                    attrib -R /L $source_path
                    # remove the junction
                    Remove-Item -Path $source_path -Recurse -Force -ErrorAction SilentlyContinue
                } else {
                    # remove the hard link
                    Remove-Item -Path $source_path -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# check whether write permission for Users usergroup is set to global persist dir, if not then set
function persist_permission($manifest, $global) {
    if ($global -and $manifest.persist -and (is_admin)) {
        $path = persistdir $null $global
        $user = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545'
        $target_rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'Write', 'ObjectInherit', 'none', 'Allow')
        $acl = Get-Acl -Path $path
        $acl.SetAccessRule($target_rule)
        $acl | Set-Acl -Path $path
    }
}

# test if there are running processes
function test_running_process($app, $global) {
    $processdir = appdir $app $global | Convert-Path
    $running_processes = Get-Process | Where-Object { $_.Path -like "$processdir\*" } | Out-String

    if ($running_processes) {
        if (get_config IGNORE_RUNNING_PROCESSES) {
            warn "The following instances of `"$app`" are still running. Scoop is configured to ignore this condition."
            Write-Host $running_processes
            return $false
        } else {
            error "The following instances of `"$app`" are still running. Close them and try again."
            Write-Host $running_processes
            return $true
        }
    } else {
        return $false
    }
}

# wrapper function to create junction links
# Required to handle docker/for-win#12240
function New-DirectoryJunction($source, $target) {
    # test if this script is being executed inside a docker container
    if (Get-Service -Name cexecsvc -ErrorAction SilentlyContinue) {
        cmd.exe /d /c "mklink /j `"$source`" `"$target`""
    } else {
        New-Item -Path $source -ItemType Junction -Value $target
    }
}
