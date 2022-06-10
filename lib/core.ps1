function Optimize-SecurityProtocol {
    # .NET Framework 4.7+ has a default security protocol called 'SystemDefault',
    # which allows the operating system to choose the best protocol to use.
    # If SecurityProtocolType contains 'SystemDefault' (means .NET4.7+ detected)
    # and the value of SecurityProtocol is 'SystemDefault', just do nothing on SecurityProtocol,
    # 'SystemDefault' will use TLS 1.2 if the webrequest requires.
    $isNewerNetFramework = ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -contains 'SystemDefault')
    $isSystemDefault = ([System.Net.ServicePointManager]::SecurityProtocol.Equals([System.Net.SecurityProtocolType]::SystemDefault))

    # If not, change it to support TLS 1.2
    if (!($isNewerNetFramework -and $isSystemDefault)) {
        # Set to TLS 1.2 (3072). Ssl3, TLS 1.0, and 1.1 have been deprecated,
        # https://datatracker.ietf.org/doc/html/rfc8996
        [System.Net.ServicePointManager]::SecurityProtocol = 3072
    }
}

function Get-UserAgent() {
    return "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64'){'WOW64; '})$PSEdition)"
}

function Show-DeprecatedWarning {
    <#
    .SYNOPSIS
        Print deprecated warning for functions, which will be deleted in near future.
    .PARAMETER Invocation
        Invocation to identify location of line.
        Just pass $MyInvocation.
    .PARAMETER New
        New command name.
    #>
    param($Invocation, [String] $New)

    warn ('"{0}" will be deprecated. Please change your code/manifest to use "{1}"' -f $Invocation.MyCommand.Name, $New)
    Write-Host "      -> $($Invocation.PSCommandPath):$($Invocation.ScriptLineNumber):$($Invocation.OffsetInLine)" -ForegroundColor DarkGray
}

function load_cfg($file) {
    if(!(Test-Path $file)) {
        return $null
    }

    try {
        # ReadAllLines will detect the encoding of the file automatically
        # Ref: https://docs.microsoft.com/en-us/dotnet/api/system.io.file.readalllines?view=netframework-4.5
        $content = [System.IO.File]::ReadAllLines($file)
        return ($content | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Write-Host "ERROR loading $file`: $($_.exception.message)"
    }
}

function get_config($name, $default) {
    if($null -eq $scoopConfig.$name -and $null -ne $default) {
        return $default
    }
    return $scoopConfig.$name
}

function set_config {
    Param (
        [ValidateNotNullOrEmpty()]
        $name,
        $value
    )

    if ($null -eq $scoopConfig -or $scoopConfig.Count -eq 0) {
        ensure (Split-Path -Path $configFile) | Out-Null
        $scoopConfig = New-Object -TypeName PSObject
    }

    if ($value -eq [bool]::TrueString -or $value -eq [bool]::FalseString) {
        $value = [System.Convert]::ToBoolean($value)
    }

    if ($null -eq $scoopConfig.$name) {
        $scoopConfig | Add-Member -MemberType NoteProperty -Name $name -Value $value
    } else {
        $scoopConfig.$name = $value
    }

    if ($null -eq $value) {
        $scoopConfig.PSObject.Properties.Remove($name)
    }

    # Save config with UTF8NoBOM encoding
    ConvertTo-Json $scoopConfig | Out-UTF8File -FilePath $configFile
    return $scoopConfig
}

function setup_proxy() {
    # note: '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
    $proxy = get_config 'proxy'
    if(!$proxy) {
        return
    }
    try {
        $credentials, $address = $proxy -split '(?<!\\)@'
        if(!$address) {
            $address, $credentials = $credentials, $null # no credentials supplied
        }

        if($address -eq 'none') {
            [net.webrequest]::defaultwebproxy = $null
        } elseif($address -ne 'default') {
            [net.webrequest]::defaultwebproxy = new-object net.webproxy "http://$address"
        }

        if($credentials -eq 'currentuser') {
            [net.webrequest]::defaultwebproxy.credentials = [net.credentialcache]::defaultcredentials
        } elseif($credentials) {
            $username, $password = $credentials -split '(?<!\\):' | ForEach-Object { $_ -replace '\\([@:])','$1' }
            [net.webrequest]::defaultwebproxy.credentials = new-object net.networkcredential($username, $password)
        }
    } catch {
        warn "Failed to use proxy '$proxy': $($_.exception.message)"
    }
}

function git_cmd {
    $proxy = get_config 'proxy'
    $cmd = "git $($args | ForEach-Object { "$_ " })"
    if ($proxy -and $proxy -ne 'none') {
        $cmd = "SET HTTPS_PROXY=$proxy&&SET HTTP_PROXY=$proxy&&$cmd"
    }
    cmd.exe /d /c $cmd
}

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }

function format($str, $hash) {
    $hash.keys | ForEach-Object { set-variable $_ $hash[$_] }
    $executionContext.invokeCommand.expandString($str)
}
function is_admin {
    $admin = [security.principal.windowsbuiltinrole]::administrator
    $id = [security.principal.windowsidentity]::getcurrent()
    ([security.principal.windowsprincipal]($id)).isinrole($admin)
}

# messages
function abort($msg, [int] $exit_code=1) { write-host $msg -f red; exit $exit_code }
function error($msg) { write-host "ERROR $msg" -f darkred }
function warn($msg) {  write-host "WARN  $msg" -f darkyellow }
function info($msg) {  write-host "INFO  $msg" -f darkgray }
function debug($obj) {
    if((get_config 'debug' $false) -ine 'true' -and $env:SCOOP_DEBUG -ine 'true') {
        return
    }

    $prefix = "DEBUG[$(Get-Date -UFormat %s)]"
    $param = $MyInvocation.Line.Replace($MyInvocation.InvocationName, '').Trim()
    $msg = $obj | Out-String -Stream

    if($null -eq $obj -or $null -eq $msg) {
        Write-Host "$prefix $param = " -f DarkCyan -NoNewline
        Write-Host '$null' -f DarkYellow -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
        return
    }

    if($msg.GetType() -eq [System.Object[]]) {
        Write-Host "$prefix $param ($($obj.GetType()))" -f DarkCyan -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
        $msg | Where-Object { ![String]::IsNullOrWhiteSpace($_) } |
            Select-Object -Skip 2 | # Skip headers
            ForEach-Object {
                Write-Host "$prefix $param.$($_)" -f DarkCyan
            }
    } else {
        Write-Host "$prefix $param = $($msg.Trim())" -f DarkCyan -NoNewline
        Write-Host " -> $($MyInvocation.PSCommandPath):$($MyInvocation.ScriptLineNumber):$($MyInvocation.OffsetInLine)" -f DarkGray
    }
}
function success($msg) { write-host $msg -f darkgreen }

function filesize($length) {
    $gb = [math]::pow(2, 30)
    $mb = [math]::pow(2, 20)
    $kb = [math]::pow(2, 10)

    if($length -gt $gb) {
        "{0:n1} GB" -f ($length / $gb)
    } elseif($length -gt $mb) {
        "{0:n1} MB" -f ($length / $mb)
    } elseif($length -gt $kb) {
        "{0:n1} KB" -f ($length / $kb)
    } else {
        if ($null -eq $length) {
            $length = 0
       }
        "$($length) B"
    }
}

# dirs
function basedir($global) { if($global) { return $globaldir } $scoopdir }
function appsdir($global) { "$(basedir $global)\apps" }
function shimdir($global) { "$(basedir $global)\shims" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }

function currentdir($app, $global) {
    if (get_config NO_JUNCTIONS) {
        $version = Select-CurrentVersion -App $app -Global:$global
    } else {
        $version = 'current'
    }
    "$(appdir $app $global)\$version"
}

function persistdir($app, $global) { "$(basedir $global)\persist\$app" }
function usermanifestsdir { "$(basedir)\workspace" }
function usermanifest($app) { "$(usermanifestsdir)\$app.json" }
function cache_path($app, $version, $url) { "$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')" }

# apps
function sanitary_path($path) { return [regex]::replace($path, "[/\\?:*<>|]", "") }
function installed($app, $global) {
    if (-not $PSBoundParameters.ContainsKey('global')) {
        return (installed $app $false) -or (installed $app $true)
    }
    # Dependencies of the format "bucket/dependency" install in a directory of form
    # "dependency". So we need to extract the bucket from the name and only give the app
    # name to is_directory
    $app = ($app -split '/|\\')[-1]
    return $null -ne (Select-CurrentVersion -AppName $app -Global:$global)
}
function installed_apps($global) {
    $dir = appsdir $global
    if (Test-Path $dir) {
        Get-ChildItem $dir | Where-Object { $_.psiscontainer -and $_.name -ne 'scoop' } | ForEach-Object { $_.name }
    }
}

# check whether the app failed to install
function failed($app, $global) {
    $app = ($app -split '/|\\')[-1]
    $appPath = appdir $app $global
    $hasCurrent = (get_config NO_JUNCTIONS) -or (Test-Path "$appPath\current")
    return (Test-Path $appPath) -and !($hasCurrent -and (installed $app $global))
}

function file_path($app, $file) {
    Show-DeprecatedWarning $MyInvocation 'Get-AppFilePath'
    Get-AppFilePath -App $app -File $file
}

function Get-AppFilePath {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $App,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $File
    )

    # normal path to file
    $Path = "$(currentdir $App $false)\$File"
    if (Test-Path $Path) {
        return $Path
    }

    # global path to file
    $Path = "$(currentdir $App $true)\$File"
    if (Test-Path $Path) {
        return $Path
    }

    # not found
    return $null
}

Function Test-CommandAvailable {
    param (
        [String]$Name
    )
    Return [Boolean](Get-Command $Name -ErrorAction Ignore)
}

function Get-HelperPath {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateSet('7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2', 'Zstd')]
        [String]
        $Helper
    )
    begin {
        $HelperPath = $null
    }
    process {
        switch ($Helper) {
            '7zip' {
                $HelperPath = Get-AppFilePath '7zip' '7z.exe'
                if ([String]::IsNullOrEmpty($HelperPath)) {
                    $HelperPath = Get-AppFilePath '7zip-zstd' '7z.exe'
                }
            }
            'Lessmsi' { $HelperPath = Get-AppFilePath 'lessmsi' 'lessmsi.exe' }
            'Innounp' { $HelperPath = Get-AppFilePath 'innounp' 'innounp.exe' }
            'Dark' {
                $HelperPath = Get-AppFilePath 'dark' 'dark.exe'
                if ([String]::IsNullOrEmpty($HelperPath)) {
                    $HelperPath = Get-AppFilePath 'wixtoolset' 'dark.exe'
                }
            }
            'Aria2' { $HelperPath = Get-AppFilePath 'aria2' 'aria2c.exe' }
            'Zstd' { $HelperPath = Get-AppFilePath 'zstd' 'zstd.exe' }
        }

        return $HelperPath
    }
}

function Get-CommandPath {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Command
    )

    begin {
        $userShims = Convert-Path (shimdir $false)
        $globalShims = fullpath (shimdir $true) # don't resolve: may not exist
    }

    process {
        try {
            $comm = Get-Command $Command -ErrorAction Stop
        } catch {
            return $null
        }
        $commandPath = if ($comm.Path -like "$userShims*" -or $comm.Path -like "$globalShims*") {
            Get-ShimTarget ($comm.Path -replace '\.exe$', '.shim')
        } elseif ($comm.CommandType -eq 'Application') {
            $comm.Source
        } elseif ($comm.CommandType -eq 'Alias') {
            Get-CommandPath $comm.ResolvedCommandName
        } else {
            $null
        }
        return $commandPath
    }
}

function Test-HelperInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateSet('7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2', 'Zstd')]
        [String]
        $Helper
    )

    return ![String]::IsNullOrWhiteSpace((Get-HelperPath -Helper $Helper))
}

function Test-Aria2Enabled {
    return (Test-HelperInstalled -Helper Aria2) -and (get_config 'aria2-enabled' $true)
}

function app_status($app, $global) {
    $status = @{}
    $status.installed = installed $app $global
    $status.version = Select-CurrentVersion -AppName $app -Global:$global
    $status.latest_version = $status.version

    $install_info = install_info $app $status.version $global

    $status.failed = failed $app $global
    $status.hold = ($install_info.hold -eq $true)

    $manifest = manifest $app $install_info.bucket $install_info.url
    $status.removed = (!$manifest)
    if ($manifest.version) {
        $status.latest_version = $manifest.version
    }

    $status.outdated = $false
    if ($status.version -and $status.latest_version) {
        if (get_config 'force_update' $false) {
            $status.outdated = ((Compare-Version -ReferenceVersion $status.version -DifferenceVersion $status.latest_version) -ne 0)
        } else {
            $status.outdated = ((Compare-Version -ReferenceVersion $status.version -DifferenceVersion $status.latest_version) -gt 0)
        }
    }

    $status.missing_deps = @()
    $deps = @($manifest.depends) | Where-Object {
        if ($null -eq $_) {
            return $null
        } else {
            $app, $bucket, $null = parse_app $_
            return !(installed $app)
        }
    }
    if ($deps) {
        $status.missing_deps += , $deps
    }

    return $status
}

function appname_from_url($url) {
    (split-path $url -leaf) -replace '.json$', ''
}

# paths
function fname($path) { split-path $path -leaf }
function strip_ext($fname) { $fname -replace '\.[^\.]*$', '' }
function strip_filename($path) { $path -replace [regex]::escape((fname $path)) }
function strip_fragment($url) { $url -replace (new-object uri $url).fragment }

function url_filename($url) {
    (split-path $url -leaf).split('?') | Select-Object -First 1
}
# Unlike url_filename which can be tricked by appending a
# URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
# this function extracts the original filename from the URL.
function url_remote_filename($url) {
    $uri = (New-Object URI $url)
    $basename = Split-Path $uri.PathAndQuery -Leaf
    If ($basename -match ".*[?=]+([\w._-]+)") {
        $basename = $matches[1]
    }
    If (($basename -notlike "*.*") -or ($basename -match "^[v.\d]+$")) {
        $basename = Split-Path $uri.AbsolutePath -Leaf
    }
    If (($basename -notlike "*.*") -and ($uri.Fragment -ne "")) {
        $basename = $uri.Fragment.Trim('/', '#')
    }
    return $basename
}

function ensure($dir) {
    if (!(Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
    Convert-Path -Path $dir
}
function fullpath($path) {
    # should be ~ rooted
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
}
function friendly_path($path) {
    $h = (Get-PsProvider 'FileSystem').home; if(!$h.endswith('\')) { $h += '\' }
    if($h -eq '\') { return $path }
    return "$path" -replace ([regex]::escape($h)), "~\"
}
function is_local($path) {
    ($path -notmatch '^https?://') -and (test-path $path)
}

# operations

function run($exe, $arg, $msg, $continue_exit_codes) {
    Show-DeprecatedWarning $MyInvocation 'Invoke-ExternalCommand'
    Invoke-ExternalCommand -FilePath $exe -ArgumentList $arg -Activity $msg -ContinueExitCodes $continue_exit_codes
}

function Invoke-ExternalCommand {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true,
                   Position = 0)]
        [Alias("Path")]
        [ValidateNotNullOrEmpty()]
        [String]
        $FilePath,
        [Parameter(Position = 1)]
        [Alias("Args")]
        [String[]]
        $ArgumentList,
        [Parameter(ParameterSetName = "UseShellExecute")]
        [Switch]
        $RunAs,
        [Alias("Msg")]
        [String]
        $Activity,
        [Alias("cec")]
        [Hashtable]
        $ContinueExitCodes,
        [Parameter(ParameterSetName = "Default")]
        [Alias("Log")]
        [String]
        $LogPath
    )
    if ($Activity) {
        Write-Host "$Activity " -NoNewline
    }
    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo.FileName = $FilePath
    $Process.StartInfo.Arguments = ($ArgumentList | Select-Object -Unique) -join ' '
    $Process.StartInfo.UseShellExecute = $false
    if ($LogPath) {
        if ($FilePath -match '(^|\W)msiexec($|\W)') {
            $Process.StartInfo.Arguments += " /lwe `"$LogPath`""
        } else {
            $Process.StartInfo.RedirectStandardOutput = $true
            $Process.StartInfo.RedirectStandardError = $true
        }
    }
    if ($RunAs) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.Verb = 'RunAs'
    }
    try {
        $Process.Start() | Out-Null
    } catch {
        if ($Activity) {
            Write-Host "error." -ForegroundColor DarkRed
        }
        error $_.Exception.Message
        return $false
    }
    if ($LogPath -and ($FilePath -notmatch '(^|\W)msiexec($|\W)')) {
        Out-UTF8File -FilePath $LogPath -Append -InputObject $Process.StandardOutput.ReadToEnd()
        Out-UTF8File -FilePath $LogPath -Append -InputObject $Process.StandardError.ReadToEnd()
    }
    $Process.WaitForExit()
    if ($Process.ExitCode -ne 0) {
        if ($ContinueExitCodes -and ($ContinueExitCodes.ContainsKey($Process.ExitCode))) {
            if ($Activity) {
                Write-Host "done." -ForegroundColor DarkYellow
            }
            warn $ContinueExitCodes[$Process.ExitCode]
            return $true
        } else {
            if ($Activity) {
                Write-Host "error." -ForegroundColor DarkRed
            }
            error "Exit code was $($Process.ExitCode)!"
            return $false
        }
    }
    if ($Activity) {
        Write-Host "done." -ForegroundColor Green
    }
    return $true
}

function dl($url,$to) {
    $wc = New-Object Net.Webclient
    $wc.headers.add('Referer', (strip_filename $url))
    $wc.Headers.Add('User-Agent', (Get-UserAgent))
    $wc.downloadFile($url,$to)
}

function env($name,$global,$val='__get') {
    $target = 'User'; if($global) {$target = 'Machine'}
    if($val -eq '__get') { [environment]::getEnvironmentVariable($name,$target) }
    else { [environment]::setEnvironmentVariable($name,$val,$target) }
}

function isFileLocked([string]$path) {
    $file = New-Object System.IO.FileInfo $path

    if ((Test-Path -Path $path) -eq $false) {
        return $false
    }

    try {
        $stream = $file.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        if ($stream) {
            $stream.Close()
        }
        return $false
    }
    catch {
        # file is locked by a process.
        return $true
    }
}

function is_directory([String] $path) {
    return (Test-Path $path) -and (Get-Item $path) -is [System.IO.DirectoryInfo]
}

function movedir($from, $to) {
    $from = $from.trimend('\')
    $to = $to.trimend('\')

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = 'robocopy.exe'
    $proc.StartInfo.Arguments = "`"$from`" `"$to`" /e /move"
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $proc.Start()
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()

    if($proc.ExitCode -ge 8) {
        debug $out
        throw "Could not find '$(fname $from)'! (error $($proc.ExitCode))"
    }

    # wait for robocopy to terminate its threads
    1..10 | ForEach-Object {
        if (Test-Path $from) {
            Start-Sleep -Milliseconds 100
        }
    }
}

function get_app_name($path) {
    if ((Test-Path (appsdir $false)) -and ($path -match "$([Regex]::Escape($(Convert-Path (appsdir $false))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } elseif ((Test-Path (appsdir $true)) -and ($path -match "$([Regex]::Escape($(Convert-Path (appsdir $true))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } else {
        $appName = ''
    }
    return $appName
}

function get_app_name_from_shim($shim) {
    if (!(Test-Path($shim))) {
        return ''
    }
    $content = (Get-Content $shim -Encoding UTF8) -join ' '
    return get_app_name $content
}

function Get-ShimTarget($ShimPath) {
    if ($ShimPath) {
        $shimTarget = if ($ShimPath.EndsWith('.shim')) {
            (Get-Content -Path $ShimPath | Select-Object -First 1).Replace('path = ', '').Replace('"', '')
        } else {
            ((Select-String -Path $ShimPath -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
        }
        if (!$shimTarget) {
            $shimTarget = ((Select-String -Path $ShimPath -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
        }
        $shimTarget | Convert-Path
    }
}

function warn_on_overwrite($shim, $path) {
    if (!(Test-Path $shim)) {
        return
    }
    $shim_app = get_app_name_from_shim $shim
    $path_app = get_app_name $path
    if ($shim_app -eq $path_app) {
        return
    } else {
        if (Test-Path -Path "$shim.$path_app" -PathType Leaf) {
            Remove-Item -Path "$shim.$path_app" -Force -ErrorAction SilentlyContinue
        }
        Rename-Item -Path $shim -NewName "$shim.$shim_app" -ErrorAction SilentlyContinue
    }
    $shimname = (fname $shim) -replace '\.shim$', '.exe'
    $filename = (fname $path) -replace '\.shim$', '.exe'
    warn "Overwriting shim ('$shimname' -> '$filename')$(if ($shim_app) { ' installed from ' + $shim_app })"
}

function shim($path, $global, $name, $arg) {
    if (!(Test-Path $path)) { abort "Can't shim '$(fname $path)': couldn't find '$path'." }
    $abs_shimdir = ensure (shimdir $global)
    ensure_in_path $abs_shimdir $global
    if (!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower())"

    # convert to relative path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path -Relative $path
    Pop-Location
    $resolved_path = Resolve-Path $path

    if ($path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        warn_on_overwrite "$shim.shim" $path
        Copy-Item (get_shim_path) "$shim.exe" -Force
        Write-Output "path = `"$resolved_path`"" | Out-UTF8File "$shim.shim"
        if ($arg) {
            Write-Output "args = $arg" | Out-UTF8File "$shim.shim" -Append
        }
    } elseif ($path -match '\.(bat|cmd)$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@`"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "MSYS2_ARG_CONV_EXCL=/C cmd.exe /C `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.ps1$') {
        # if $path points to another drive resolve-path prepends .\ which could break shims
        warn_on_overwrite "$shim.ps1" $path
        $ps1text = if ($relative_path -match '^(\.\\)?\w:.*$') {
            @(
                "# $resolved_path",
                "`$path = `"$path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                "exit `$LASTEXITCODE"
            )
        } else {
            @(
                "# $resolved_path",
                "`$path = Join-Path `$PSScriptRoot `"$relative_path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                "exit `$LASTEXITCODE"
            )
        }
        $ps1text -join "`r`n" | Out-UTF8File "$shim.ps1"

        # make ps1 accessible from cmd.exe
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@echo off",
            "where /q pwsh.exe",
            "if %errorlevel% equ 0 (",
            "    pwsh -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
            ") else (",
            "    powershell -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
            ")"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if command -v pwsh.exe > /dev/null 2>&1; then",
            "    pwsh.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
            "else",
            "    powershell.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
            "fi"
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.jar$') {
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@java -jar `"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "java.exe -jar `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.py$') {
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@python `"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "python.exe `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } else {
        warn_on_overwrite "$shim.cmd" $path
        # find path to Git's bash so that batch scripts can run bash scripts
        $gitdir = (Get-Item (Get-CommandPath git) -ErrorAction:Stop).Directory.Parent
        if ($gitdir.FullName -imatch 'mingw') {
            $gitdir = $gitdir.Parent
        }
        @(
            "@rem $resolved_path",
            "@`"$(Join-Path (Join-Path $gitdir.FullName 'bin') 'bash.exe')`" `"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "`"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    }
}

function get_shim_path() {
    $shim_path = "$(versiondir 'scoop' 'current')\supporting\shims\kiennq\shim.exe"
    $shim_version = get_config 'shim' 'default'
    switch ($shim_version) {
        '71' { $shim_path = "$(versiondir 'scoop' 'current')\supporting\shims\71\shim.exe"; Break }
        'scoopcs' { $shim_path = "$(versiondir 'scoop' 'current')\supporting\shimexe\bin\shim.exe"; Break }
        'kiennq' { Break } # for backward compatibility
        'default' { Break }
        default { warn "Unknown shim version: '$shim_version'" }
    }
    return $shim_path
}

function search_in_path($target) {
    $path = (env 'PATH' $false) + ";" + (env 'PATH' $true)
    foreach($dir in $path.split(';')) {
        if(test-path "$dir\$target" -pathType leaf) {
            return "$dir\$target"
        }
    }
}

function ensure_in_path($dir, $global) {
    $path = env 'PATH' $global
    $dir = fullpath $dir
    if($path -notmatch [regex]::escape($dir)) {
        write-output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."

        env 'PATH' $global "$dir;$path" # for future sessions...
        $env:PATH = "$dir;$env:PATH" # for this session
    }
}

function ensure_architecture($architecture_opt) {
    if(!$architecture_opt) {
        return default_architecture
    }
    $architecture_opt = $architecture_opt.ToString().ToLower()
    switch($architecture_opt) {
        { @('64bit', '64', 'x64', 'amd64', 'x86_64', 'x86-64')  -contains $_ } { return '64bit' }
        { @('32bit', '32', 'x86', 'i386', '386', 'i686')  -contains $_ } { return '32bit' }
        default { throw [System.ArgumentException] "Invalid architecture: '$architecture_opt'"}
    }
}

function Confirm-InstallationStatus {
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]
        $Apps,
        [Switch]
        $Global
    )
    $Installed = @()
    $Apps | Select-Object -Unique | Where-Object { $_.Name -ne 'scoop' } | ForEach-Object {
        $App, $null, $null = parse_app $_
        if ($Global) {
            if (Test-Path (appdir $App $true)) {
                $Installed += , @($App, $true)
            } elseif (Test-Path (appdir $App $false)) {
                error "'$App' isn't installed globally, but it may be installed locally."
                warn "Try again without the --global (or -g) flag instead."
            } else {
                error "'$App' isn't installed."
            }
        } else {
            if (Test-Path (appdir $App $false)) {
                $Installed += , @($App, $false)
            } elseif (Test-Path (appdir $App $true)) {
                error "'$App' isn't installed locally, but it may be installed globally."
                warn "Try again with the --global (or -g) flag instead."
            } else {
                error "'$App' isn't installed."
            }
        }
        if (failed $App $Global) {
            error "'$App' isn't installed correctly."
        }
    }
    return , $Installed
}

function strip_path($orig_path, $dir) {
    if($null -eq $orig_path) { $orig_path = '' }
    $stripped = [string]::join(';', @( $orig_path.split(';') | Where-Object { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
}

function add_first_in_path($dir, $global) {
    $dir = fullpath $dir

    # future sessions
    $null, $currpath = strip_path (env 'path' $global) $dir
    env 'path' $global "$dir;$currpath"

    # this session
    $null, $env:PATH = strip_path $env:PATH $dir
    $env:PATH = "$dir;$env:PATH"
}

function remove_from_path($dir, $global) {
    $dir = fullpath $dir

    # future sessions
    $was_in_path, $newpath = strip_path (env 'path' $global) $dir
    if($was_in_path) {
        Write-Output "Removing $(friendly_path $dir) from your path."
        env 'path' $global $newpath
    }

    # current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if($was_in_path) { $env:PATH = $newpath }
}

function ensure_robocopy_in_path {
    if(!(Test-CommandAvailable robocopy)) {
        shim "C:\Windows\System32\Robocopy.exe" $false
    }
}

function wraptext($text, $width) {
    if(!$width) { $width = $host.ui.rawui.buffersize.width };
    $width -= 1 # be conservative: doesn't seem to print the last char

    $text -split '\r?\n' | ForEach-Object {
        $line = ''
        $_ -split ' ' | ForEach-Object {
            if($line.length -eq 0) { $line = $_ }
            elseif($line.length + $_.length + 1 -le $width) { $line += " $_" }
            else { $lines += ,$line; $line = $_ }
        }
        $lines += ,$line
    }

    $lines -join "`n"
}

function pluralize($count, $singular, $plural) {
    if($count -eq 1) { $singular } else { $plural }
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
    if(!$apps) { return @() }
    return ,@($apps | ForEach-Object { ,@($_, $global) })
}

function parse_app([string]$app) {
    if ($app -match '^(?:(?<bucket>[a-zA-Z0-9-_.]+)/)?(?<app>.*\.json$|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?$') {
        return $Matches['app'], $Matches['bucket'], $Matches['version']
    } else {
        return $app, $null, $null
    }
}

function show_app($app, $bucket, $version) {
    if($bucket) {
        $app = "$bucket/$app"
    }
    if($version) {
        $app = "$app@$version"
    }
    return $app
}

function last_scoop_update() {
    # PowerShell 6 returns an DateTime Object
    $last_update = (get_config lastupdate)

    if ($null -ne $last_update -and $last_update.GetType() -eq [System.String]) {
        try {
            $last_update = [System.DateTime]::Parse($last_update)
        } catch {
            $last_update = $null
        }
    }
    return $last_update
}

function is_scoop_outdated() {
    $last_update = $(last_scoop_update)
    $now = [System.DateTime]::Now
    if($null -eq $last_update) {
        set_config lastupdate $now.ToString('o')
        # enforce an update for the first time
        return $true
    }
    return $last_update.AddHours(3) -lt $now.ToLocalTime()
}

function substitute($entity, [Hashtable] $params, [Bool]$regexEscape = $false) {
    $newentity = $entity
    if ($null -ne $newentity) {
        switch ($entity.GetType().Name) {
            'String' {
                $params.GetEnumerator() | ForEach-Object {
                    if ($regexEscape -eq $false -or $null -eq $_.Value) {
                        $newentity = $newentity.Replace($_.Name, $_.Value)
                    } else {
                        $newentity = $newentity.Replace($_.Name, [Regex]::Escape($_.Value))
                    }
                }
            }
            'Object[]' {
                $newentity = $entity | ForEach-Object { ,(substitute $_ $params $regexEscape) }
            }
            'PSCustomObject' {
                $newentity.PSObject.Properties | ForEach-Object { $_.Value = substitute $_.Value $params $regexEscape }
            }
        }
    }
    return $newentity
}

function format_hash([String] $hash) {
    $hash = $hash.toLower()
    switch ($hash.Length)
    {
        32 { $hash = "md5:$hash" } # md5
        40 { $hash = "sha1:$hash" } # sha1
        64 { $hash = $hash } # sha256
        128 { $hash = "sha512:$hash" } # sha512
        default { $hash = $null }
    }
    return $hash
}

function format_hash_aria2([String] $hash) {
    $hash = $hash -split ':' | Select-Object -Last 1
    switch ($hash.Length)
    {
        32 { $hash = "md5=$hash" } # md5
        40 { $hash = "sha-1=$hash" } # sha1
        64 { $hash = "sha-256=$hash" } # sha256
        128 { $hash = "sha-512=$hash" } # sha512
        default { $hash = $null }
    }
    return $hash
}

function get_hash([String] $multihash) {
    $type, $hash = $multihash -split ':'
    if(!$hash) {
        # no type specified, assume sha256
        $type, $hash = 'sha256', $multihash
    }

    if(@('md5','sha1','sha256', 'sha512') -notcontains $type) {
        return $null, "Hash type '$type' isn't supported."
    }

    return $type, $hash.ToLower()
}

function Get-GitHubToken {
    return $env:SCOOP_GH_TOKEN, (get_config 'gh_token') | Where-Object -Property Length -Value 0 -GT | Select-Object -First 1
}

function handle_special_urls($url)
{
    # FossHub.com
    if ($url -match "^(?:.*fosshub.com\/)(?<name>.*)(?:\/|\?dwl=)(?<filename>.*)$") {
        $Body = @{
            projectUri      = $Matches.name;
            fileName        = $Matches.filename;
            source          = 'CF';
            isLatestVersion = $true
        }
        if ((Invoke-RestMethod -Uri $url) -match '"p":"(?<pid>[a-f0-9]{24}).*?"r":"(?<rid>[a-f0-9]{24})') {
            $Body.Add("projectId", $Matches.pid)
            $Body.Add("releaseId", $Matches.rid)
        }
        $url = Invoke-RestMethod -Method Post -Uri "https://api.fosshub.com/download/" -ContentType "application/json" -Body (ConvertTo-Json $Body -Compress)
        if ($null -eq $url.error) {
            $url = $url.data.url
        }
    }

    # Sourceforge.net
    if ($url -match "(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*?)(?:$|\/download|\?)") {
        # Reshapes the URL to avoid redirections
        $url = "https://downloads.sourceforge.net/project/$($matches['project'])/$($matches['file'])"
    }

    # Github.com
    if ($url -match 'github.com/(?<owner>[^/]+)/(?<repo>[^/]+)/releases/download/(?<tag>[^/]+)/(?<file>[^/#]+)(?<filename>.*)' -and ($token = Get-GitHubToken)) {
        $headers = @{ "Authorization" = "token $token" }
        $privateUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)"
        $assetUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)/releases/tags/$($Matches.tag)"

        if ((Invoke-RestMethod -Uri $privateUrl -Headers $headers).Private) {
            $url = ((Invoke-RestMethod -Uri $assetUrl -Headers $headers).Assets | Where-Object -Property Name -EQ -Value $Matches.file).Url, $Matches.filename -join ''
        }
    }

    return $url
}

function get_magic_bytes($file) {
    if(!(Test-Path $file)) {
        return ''
    }

    if((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
        # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
        return Get-Content $file -AsByteStream -TotalCount 8
    }
    else {
        return Get-Content $file -Encoding byte -TotalCount 8
    }
}

function get_magic_bytes_pretty($file, $glue = ' ') {
    if(!(Test-Path $file)) {
        return ''
    }

    return (get_magic_bytes $file | ForEach-Object { $_.ToString('x2') }) -join $glue
}

function Out-UTF8File {
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [Alias("Path")]
        [String] $FilePath,
        [Switch] $Append,
        [Switch] $NoNewLine,
        [Parameter(ValueFromPipeline = $True)]
        [PSObject] $InputObject
    )
    process {
        if ($Append) {
            [System.IO.File]::AppendAllText($FilePath, $InputObject)
        } else {
            if (!$NoNewLine) {
                # Ref: https://stackoverflow.com/questions/5596982
                # Performance Note: `WriteAllLines` throttles memory usage while
                # `WriteAllText` needs to keep the complete string in memory.
                [System.IO.File]::WriteAllLines($FilePath, $InputObject)
            } else {
                # However `WriteAllText` does not add ending newline.
                [System.IO.File]::WriteAllText($FilePath, $InputObject)
            }
        }
    }
}

##################
# Core Bootstrap #
##################

# Note: Github disabled TLS 1.0 support on 2018-02-23. Need to enable TLS 1.2
#       for all communication with api.github.com
Optimize-SecurityProtocol

# Scoop config file migration
$configHome = $env:XDG_CONFIG_HOME, "$env:USERPROFILE\.config" | Select-Object -First 1
$configFile = "$configHome\scoop\config.json"
if ((Test-Path "$env:USERPROFILE\.scoop") -and !(Test-Path $configFile)) {
    New-Item -ItemType Directory (Split-Path -Path $configFile) -ErrorAction Ignore | Out-Null
    Move-Item "$env:USERPROFILE\.scoop" $configFile
    write-host "WARN  Scoop configuration has been migrated from '~/.scoop'" -f darkyellow
    write-host "WARN  to '$configFile'" -f darkyellow
}

# Load Scoop config
$scoopConfig = load_cfg $configFile

# Scoop root directory
$scoopdir = $env:SCOOP, (get_config 'rootPath'), "$env:USERPROFILE\scoop" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1

# Scoop global apps directory
$globaldir = $env:SCOOP_GLOBAL, (get_config 'globalPath'), "$env:ProgramData\scoop" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -first 1

# Scoop cache directory
# Note: Setting the SCOOP_CACHE environment variable to use a shared directory
#       is experimental and untested. There may be concurrency issues when
#       multiple users write and access cached files at the same time.
#       Use at your own risk.
$cachedir = $env:SCOOP_CACHE, (get_config 'cachePath'), "$scoopdir\cache" | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -first 1

# Setup proxy globally
setup_proxy
