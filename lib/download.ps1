# Description: Functions for downloading files

function Get-RemoteFile {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [uri]
        $Uri,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [string]
        $OutFile,
        [hashtable]
        $Cookies,
        [string]
        $UserAgent,
        [int]
        $TimeoutSec,
        [Microsoft.PowerShell.Commands.WebRequestMethod]
        [ValidateSet('Get', 'Head', 'Post')]
        $Method
    )

    begin {
        $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $webRequestArgs = @{
            UseBasicParsing = $true
            WebSession      = $session
        }
        $session.UserAgent = if ($UserAgent) { $UserAgent } else { Get-UserAgent }
        if ($Cookies) {
            $session.Headers.Add('Cookie', (cookie_header $Cookies))
        }
        if ($TimeoutSec) {
            $webRequestArgs.Add('TimeoutSec', $TimeoutSec)
        }
        if ($Method -notin @($null, 'Get')) {
            $webRequestArgs.Add('Method', $Method)
        }
    }

    process {
        $session.Headers.Add('Referer', $Uri.GetComponents([System.UriComponents]::SchemeAndServer, [System.UriFormat]::UriEscaped))
        # if (-not ($Uri -match 'sourceforge\.net' -or $Uri -match 'portableapps\.com')) {
        #     $session.Referer = strip_filename $Uri
        # }
        get_config PRIVATE_HOSTS | Where-Object { $_ -ne $null -and $Uri -match $_.match } | ForEach-Object {
            (ConvertFrom-StringData -StringData $_.Headers).GetEnumerator() | ForEach-Object {
                $session.Headers.Add($_.Key, $_.Value)
            }
        }
        $GitHubToken = Get-GitHubToken
        if ($Uri.Host -eq 'api.github.com' -and $GitHubToken) {
            $session.Headers.Add('Authorization', "Bearer $GitHubToken")
            $session.Headers.Add('X-GitHub-Api-Version', '2022-11-28')
        }
        if ($OutFile) {
            $webRequestArgs.Add('OutFile', $OutFile)
            $webRequestArgs.Add('PassThru', $true)
        }
        $ProgressPreference = 'SilentlyContinue'
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri @webRequestArgs
            $result = switch ($Method) {
                'Head' { $response.Headers }
                Default { $response.Content }
            }
        } catch {
            $result = @{
                StatusCode   = $_.Exception.Response.StatusCode.value__
                ReasonPhrase = $_.Exception.Response.ReasonPhrase
            }
        }
        return $result
    }
}

function Get-RemoteFileSize ($Uri) {
    $result = Get-RemoteFile -Uri $Uri -Method Head
    if (!$result.StatusCode) {
        $result.'Content-Length' | ForEach-Object { [int]$_ }
    }
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

    # can be multiple urls: if there are, then installer should go first to make 'installer.args' section work
    $urls = @(script:url $manifest $architecture)

    # can be multiple cookies: they will be used for all HTTP requests.
    $cookies = $manifest.cookie

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

    return $urls.ForEach({ url_filename $_ })
}

function cookie_header($cookies) {
    if ($cookies) {
        return $cookies.PSObject.Properties.ForEach({ "$($_.Name)=$($_.Value)" }) -join ';'
    }
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

function get_hash([String] $multihash) {
    $type, $hash = $multihash -split ':'
    if (!$hash) {
        # no type specified, assume sha256
        $type, $hash = 'sha256', $multihash
    }

    if (@('md5', 'sha1', 'sha256', 'sha512') -notcontains $type) {
        return $null, "Hash type '$type' isn't supported."
    }

    return $type, $hash.ToLower()
}

function Get-GitHubToken {
    return $env:SCOOP_GH_TOKEN, (get_config GH_TOKEN) | Where-Object -Property Length -Value 0 -GT | Select-Object -First 1
}

function github_ratelimit_reached {
    $api_link = 'https://api.github.com/rate_limit'
    $ret = (Get-RemoteFile $api_link | ConvertFrom-Json).rate.remaining -eq 0
    if ($ret) {
        Write-Host "GitHub API rate limit reached.`r`nPlease try again later or configure your API token using 'scoop config gh_token <your token>'."
    }
    $ret
}

function handle_special_urls($url) {
    # FossHub.com
    if ($url -match '^(?:.*fosshub.com\/)(?<name>.*)(?:\/|\?dwl=)(?<filename>.*)$') {
        $Body = @{
            projectUri      = $Matches.name
            fileName        = $Matches.filename
            source          = 'CF'
            isLatestVersion = $true
        }
        if ((Invoke-RestMethod -Uri $url) -match '"p":"(?<pid>[a-f0-9]{24}).*?"r":"(?<rid>[a-f0-9]{24})') {
            $Body.Add('projectId', $Matches.pid)
            $Body.Add('releaseId', $Matches.rid)
        }
        $url = Invoke-RestMethod -Method Post -Uri 'https://api.fosshub.com/download/' -ContentType 'application/json' -Body (ConvertTo-Json $Body -Compress)
        if ($null -eq $url.error) {
            $url = $url.data.url
        }
    }

    # Sourceforge.net
    if ($url -match '(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*?)(?:$|\/download|\?)') {
        # Reshapes the URL to avoid redirections
        $url = "https://downloads.sourceforge.net/project/$($matches['project'])/$($matches['file'])"
    }

    # Github.com
    if ($url -match 'github.com/(?<owner>[^/]+)/(?<repo>[^/]+)/releases/download/(?<tag>[^/]+)/(?<file>[^/#]+)(?<filename>.*)' -and ($token = Get-GitHubToken)) {
        $headers = @{ 'Authorization' = "token $token" }
        $privateUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)"
        $assetUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)/releases/tags/$($Matches.tag)"

        if ((Invoke-RestMethod -Uri $privateUrl -Headers $headers).Private) {
            $url = ((Invoke-RestMethod -Uri $assetUrl -Headers $headers).Assets | Where-Object -Property Name -EQ -Value $Matches.file).Url, $Matches.filename -join ''
        }
    }

    return $url
}

function get_magic_bytes($file) {
    if (!(Test-Path $file)) {
        return ''
    }

    if ((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
        # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
        return Get-Content $file -AsByteStream -TotalCount 8
    } else {
        return Get-Content $file -Encoding byte -TotalCount 8
    }
}

function get_magic_bytes_pretty($file, $glue = ' ') {
    if (!(Test-Path $file)) {
        return ''
    }

    return (get_magic_bytes $file | ForEach-Object { $_.ToString('x2') }) -join $glue
}

function Get-Encoding($wc) {
    if ($null -ne $wc.ResponseHeaders -and $wc.ResponseHeaders['Content-Type'] -match 'charset=([^;]*)') {
        return [System.Text.Encoding]::GetEncoding($Matches[1])
    } else {
        return [System.Text.Encoding]::GetEncoding('utf-8')
    }
}

function Get-UserAgent() {
    return "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}

function setup_proxy() {
    # note: '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
    $proxy = get_config PROXY
    if (!$proxy) {
        return
    }
    try {
        $credentials, $address = $proxy -split '(?<!\\)@'
        if (!$address) {
            $address, $credentials = $credentials, $null # no credentials supplied
        }

        if ($address -eq 'none') {
            [net.webrequest]::defaultwebproxy = $null
        } elseif ($address -ne 'default') {
            [net.webrequest]::defaultwebproxy = New-Object net.webproxy "http://$address"
        }

        if ($credentials -eq 'currentuser') {
            [net.webrequest]::defaultwebproxy.credentials = [net.credentialcache]::defaultcredentials
        } elseif ($credentials) {
            $username, $password = $credentials -split '(?<!\\):' | ForEach-Object { $_ -replace '\\([@:])', '$1' }
            [net.webrequest]::defaultwebproxy.credentials = New-Object net.networkcredential($username, $password)
        }
    } catch {
        warn "Failed to use proxy '$proxy': $($_.exception.message)"
    }
}

function Test-Aria2Enabled {
    return (Test-HelperInstalled -Helper Aria2) -and (get_config 'aria2-enabled' $true)
}

function url_filename($url) {
    (Split-Path $url -Leaf).split('?') | Select-Object -First 1
}

# Unlike url_filename which can be tricked by appending a
# URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
# this function extracts the original filename from the URL.
function url_remote_filename($url) {
    $uri = (New-Object URI $url)
    $basename = Split-Path $uri.PathAndQuery -Leaf
    If ($basename -match '.*[?=]+([\w._-]+)') {
        $basename = $matches[1]
    }
    If (($basename -notlike '*.*') -or ($basename -match '^[v.\d]+$')) {
        $basename = Split-Path $uri.AbsolutePath -Leaf
    }
    If (($basename -notlike '*.*') -and ($uri.Fragment -ne '')) {
        $basename = $uri.Fragment.Trim('/', '#')
    }
    return $basename
}

# Setup proxy globally
setup_proxy
