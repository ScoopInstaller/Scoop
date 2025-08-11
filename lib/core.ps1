function Get-PESubsystem($filePath) {
    try {
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)

        $fileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $binaryReader.ReadInt32()

        $fileStream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fileHeaderOffset = $fileStream.Position

        $fileStream.Seek(18, [System.IO.SeekOrigin]::Current) | Out-Null
        $fileStream.Seek($fileHeaderOffset + 0x5C, [System.IO.SeekOrigin]::Begin) | Out-Null

        return $binaryReader.ReadInt16()
    } catch {
        return -1
    } finally {
        $binaryReader.Close()
        $fileStream.Close()
    }
}

function Set-PESubsystem($filePath, $targetSubsystem) {
    try {
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)
        $binaryWriter = [System.IO.BinaryWriter]::new($fileStream)

        $fileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $binaryReader.ReadInt32()

        $fileStream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fileHeaderOffset = $fileStream.Position

        $fileStream.Seek(18, [System.IO.SeekOrigin]::Current) | Out-Null
        $fileStream.Seek($fileHeaderOffset + 0x5C, [System.IO.SeekOrigin]::Begin) | Out-Null

        $binaryWriter.Write([System.Int16] $targetSubsystem)
    } catch {
        return $false
    } finally {
        $binaryReader.Close()
        $fileStream.Close()
    }
    return $true
}

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
    $name = $name.ToLowerInvariant()
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

    $name = $name.ToLowerInvariant()

    if ($null -eq $scoopConfig -or $scoopConfig.Count -eq 0) {
        ensure (Split-Path -Path $configFile) | Out-Null
        $scoopConfig = New-Object -TypeName PSObject
    }

    if ($value -eq [bool]::TrueString -or $value -eq [bool]::FalseString) {
        $value = [System.Convert]::ToBoolean($value)
    }

    # Initialize config's change
    Complete-ConfigChange -Name $name -Value $value

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

function Complete-ConfigChange {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Name,
        [Parameter(Mandatory, Position = 1)]
        [AllowEmptyString()]
        [string]
        $Value
    )

    if ($Name -eq 'use_isolated_path') {
        $oldValue = get_config USE_ISOLATED_PATH
        if ($Value -eq $oldValue) {
            return
        } else {
            $currPathEnvVar = $scoopPathEnvVar
        }
        . "$PSScriptRoot\..\lib\system.ps1"

        if ($Value -eq $false -or $Value -eq '') {
            info 'Turn off Scoop isolated path... This may take a while, please wait.'
            $movedPath = Get-EnvVar -Name $currPathEnvVar
            if ($movedPath) {
                Add-Path -Path $movedPath -Quiet
                Remove-Path -Path ('%' + $currPathEnvVar + '%') -Quiet
                Set-EnvVar -Name $currPathEnvVar -Quiet
            }
            if (is_admin) {
                $movedPath = Get-EnvVar -Name $currPathEnvVar -Global
                if ($movedPath) {
                    Add-Path -Path $movedPath -Global -Quiet
                    Remove-Path -Path ('%' + $currPathEnvVar + '%') -Global -Quiet
                    Set-EnvVar -Name $currPathEnvVar -Global -Quiet
                }
            }
        } else {
            $newPathEnvVar = if ($Value -eq $true) {
                'SCOOP_PATH'
            } else {
                $Value.ToUpperInvariant()
            }
            info "Turn on Scoop isolated path ('$newPathEnvVar')... This may take a while, please wait."
            $movedPath = Remove-Path -Path "$scoopdir\apps\*" -TargetEnvVar $currPathEnvVar -Quiet -PassThru
            if ($movedPath) {
                Add-Path -Path $movedPath -TargetEnvVar $newPathEnvVar -Quiet
                Add-Path -Path ('%' + $newPathEnvVar + '%') -Quiet
                if ($currPathEnvVar -ne 'PATH') {
                    Remove-Path -Path ('%' + $currPathEnvVar + '%') -Quiet
                    Set-EnvVar -Name $currPathEnvVar -Quiet
                }
            }
            if (is_admin) {
                $movedPath = Remove-Path -Path "$globaldir\apps\*" -TargetEnvVar $currPathEnvVar -Global -Quiet -PassThru
                if ($movedPath) {
                    Add-Path -Path $movedPath -TargetEnvVar $newPathEnvVar -Global -Quiet
                    Add-Path -Path ('%' + $newPathEnvVar + '%') -Global -Quiet
                    if ($currPathEnvVar -ne 'PATH') {
                        Remove-Path -Path ('%' + $currPathEnvVar + '%') -Global -Quiet
                        Set-EnvVar -Name $currPathEnvVar -Global -Quiet
                    }
                }
            }
        }
    }

    if ($Name -eq 'use_sqlite_cache' -and $Value -eq $true) {
        if ((Get-DefaultArchitecture) -eq 'arm64') {
            abort 'SQLite cache is not supported on ARM64 platform.'
        }
        . "$PSScriptRoot\..\lib\database.ps1"
        . "$PSScriptRoot\..\lib\manifest.ps1"
        info 'Initializing SQLite cache in progress... This may take a while, please wait.'
        Set-ScoopDB
    }
}

function setup_proxy() {
    # note: '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
    $proxy = get_config PROXY
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

function Invoke-Git {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('PSPath', 'Path')]
        [ValidateNotNullOrEmpty()]
        [String]
        $WorkingDirectory,
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('Args')]
        [String[]]
        $ArgumentList
    )

    $proxy = get_config PROXY
    $git = Get-HelperPath -Helper Git

    if ($WorkingDirectory) {
        $ArgumentList = @('-C', $WorkingDirectory) + $ArgumentList
    }

    if([String]::IsNullOrEmpty($proxy) -or $proxy -eq 'none')  {
        return & $git @ArgumentList
    }

    if($ArgumentList -Match '\b(clone|checkout|pull|fetch|ls-remote)\b') {
        $j = Start-Job -ScriptBlock {
            # convert proxy setting for git
            $proxy = $using:proxy
            if ($proxy -and $proxy.StartsWith('currentuser@')) {
                $proxy = $proxy.Replace('currentuser@', ':@')
            }
            $env:HTTPS_PROXY = $proxy
            $env:HTTP_PROXY = $proxy
            & $using:git @using:ArgumentList
        }
        $o = $j | Receive-Job -Wait -AutoRemoveJob
        return $o
    }

    return & $git @ArgumentList
}

function Invoke-GitLog {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Path,
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$CommitHash,
        [String]$Name = ''
    )
    Process {
        if ($Name) {
            if ($Name.Length -gt 12) {
                $Name = "$($Name.Substring(0, 10)).."
            }
            $Name = "%Cgreen$($Name.PadRight(12, ' ').Substring(0, 12))%Creset "
        }
        Invoke-Git -Path $Path -ArgumentList @('--no-pager', 'log', '--color', '--no-decorate', "--grep='^(chore)'", '--invert-grep', '--abbrev=12', "--format=tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s $Name%C(cyan)%cr%Creset", "$CommitHash..HEAD")
    }
}

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }

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
    if ((get_config DEBUG $false) -ine 'true' -and $env:SCOOP_DEBUG -ine 'true') {
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
function modulesdir($global) { "$(basedir $global)\modules" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }

function currentdir($app, $global) {
    if (get_config NO_JUNCTION) {
        $version = Select-CurrentVersion -App $app -Global:$global
    } else {
        $version = 'current'
    }
    "$(appdir $app $global)\$version"
}

function persistdir($app, $global) { "$(basedir $global)\persist\$app" }
function usermanifestsdir { "$(basedir)\workspace" }
function usermanifest($app) { "$(usermanifestsdir)\$app.json" }
function cache_path($app, $version, $url) {
    $underscoredUrl = $url -replace '[^\w\.\-]+', '_'
    $filePath = Join-Path $cachedir "$app#$version#$underscoredUrl"

    # NOTE: Scoop cache files migration. Remove this 6 months after the feature ships.
    if (Test-Path $filePath) {
        return $filePath
    }

    $urlStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($url))
    $sha = (Get-FileHash -Algorithm SHA256 -InputStream $urlStream).Hash.ToLower().Substring(0, 7)
    $extension = [System.IO.Path]::GetExtension($url)
    $filePath = $filePath -replace "$underscoredUrl", "$sha$extension"

    return $filePath
}

# apps
function sanitary_path($path) { return [regex]::replace($path, "[/\\?:*<>|]", "") }
function installed($app, [Nullable[bool]]$global) {
    if ($null -eq $global) {
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
    $hasCurrent = (get_config NO_JUNCTION) -or (Test-Path "$appPath\current")
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

Function Test-GitAvailable {
    return [Boolean](Get-HelperPath -Helper Git)
}

function Get-HelperPath {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateSet('Git', '7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2')]
        [String]
        $Helper
    )
    begin {
        $HelperPath = $null
    }
    process {
        switch ($Helper) {
            'Git' {
                $internalgit = (Get-AppFilePath 'git' 'mingw64\bin\git.exe'), (Get-AppFilePath 'git' 'mingw32\bin\git.exe') | Where-Object { $_ -ne $null }
                if ($internalgit) {
                    $HelperPath = $internalgit
                } else {
                    $HelperPath = (Get-Command git -CommandType Application -TotalCount 1 -ErrorAction Ignore).Source
                }
            }
            '7zip' { $HelperPath = Get-AppFilePath '7zip' '7z.exe' }
            'Lessmsi' { $HelperPath = Get-AppFilePath 'lessmsi' 'lessmsi.exe' }
            'Innounp' {
                $HelperPath = Get-AppFilePath 'innounp-unicode' 'innounp.exe'
                if ([String]::IsNullOrEmpty($HelperPath)) {
                    $HelperPath = Get-AppFilePath 'innounp' 'innounp.exe'
                }
            }
            'Dark' {
                $HelperPath = Get-AppFilePath 'wixtoolset' 'wix.exe'
                if ([String]::IsNullOrEmpty($HelperPath)) {
                    $HelperPath = Get-AppFilePath 'dark' 'dark.exe'
                }
            }
            'Aria2' { $HelperPath = Get-AppFilePath 'aria2' 'aria2c.exe' }
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
        $userShims = shimdir $false
        $globalShims = shimdir $true
    }

    process {
        try {
            $comm = Get-Command $Command -ErrorAction Stop
        } catch {
            return $null
        }
        $commandPath = if ($comm.Path -like "$userShims\scoop-*.ps1") {
            # Scoop aliases
            $comm.Source
        } elseif ($comm.Path -like "$userShims*" -or $comm.Path -like "$globalShims*") {
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
        [ValidateSet('7zip', 'Lessmsi', 'Innounp', 'Dark', 'Aria2')]
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
        if (get_config FORCE_UPDATE $false) {
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
function Get-AbsolutePath {
    <#
    .SYNOPSIS
        Get absolute path
    .DESCRIPTION
        Get absolute path, even if not existed
    .PARAMETER Path
        Path to manipulate
    .OUTPUTS
        System.String
            Absolute path, may or maynot existed
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path
    )
    process {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
}

function fullpath($path) {
    Show-DeprecatedWarning $MyInvocation 'Get-AbsolutePath'
    return Get-AbsolutePath -Path $path
}
function friendly_path($path) {
    $h = (Get-PSProvider 'FileSystem').Home
    if (!$h.EndsWith('\')) {
        $h += '\'
    }
    if ($h -eq '\') {
        return $path
    } else {
        return $path -replace ([Regex]::Escape($h)), '~\'
    }
}
function is_local($path) {
    ($path -notmatch '^https?://') -and (Test-Path $path)
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
        [Parameter(Mandatory = $true, Position = 0)]
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
        [Parameter(ParameterSetName = "UseShellExecute")]
        [Switch]
        $Quiet,
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
    $Process.StartInfo.UseShellExecute = $false
    if ($LogPath) {
        if ($FilePath -match '^msiexec(.exe)?$') {
            $ArgumentList += "/lwe `"$LogPath`""
        } else {
            $redirectToLogFile = $true
            $Process.StartInfo.RedirectStandardOutput = $true
            $Process.StartInfo.RedirectStandardError = $true
        }
    }
    if ($RunAs) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.Verb = 'RunAs'
    }
    if ($Quiet) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    }
    if ($ArgumentList.Length -gt 0) {
        # Remove existing double quotes and split arguments
        # '(?<=(?<![:\w])[/-]\w+) ' matches a space after a command line switch starting with a slash ('/') or a hyphen ('-')
        # The inner item '(?<![:\w])[/-]' matches a slash ('/') or a hyphen ('-') not preceded by a colon (':') or a word character ('\w')
        # so that it must be a command line switch, otherwise, it would be a path (e.g. 'C:/Program Files') or other word (e.g. 'some-arg')
        # ' (?=[/-])' matches a space followed by a slash ('/') or a hyphen ('-'), i.e. the space before a command line switch
        $ArgumentList = $ArgumentList.ForEach({ $_ -replace '"' -split '(?<=(?<![:\w])[/-]\w+) | (?=[/-])' })
        # Use legacy argument escaping for commands having non-standard behavior with regard to argument passing.
        # `msiexec` requires some args like `TARGETDIR="C:\Program Files"`, which is non-standard, therefore we treat it as a legacy command.
        # NSIS installer's '/D' param may not work with the ArgumentList property, so we need to escape arguments manually.
        # ref-1: https://learn.microsoft.com/en-us/powershell/scripting/learn/experimental-features?view=powershell-7.4#psnativecommandargumentpassing
        # ref-2: https://nsis.sourceforge.io/Docs/Chapter3.html
        $LegacyCommand = $FilePath -match '^((cmd|cscript|find|sqlcmd|wscript|msiexec)(\.exe)?|.*\.(bat|cmd|js|vbs|wsf))$' -or
            ($ArgumentList -match '^/S$|^/D=[A-Z]:[\\/].*$').Length -eq 2
        $SupportArgumentList = $Process.StartInfo.PSObject.Properties.Name -contains 'ArgumentList'
        if ((-not $LegacyCommand) -and $SupportArgumentList) {
            # ArgumentList is supported in PowerShell 6.1 and later (built on .NET Core 2.1+)
            # ref-1: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-6.0
            # ref-2: https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2#net-framework-vs-net-core
            $ArgumentList.ForEach({ $Process.StartInfo.ArgumentList.Add($_) })
        } else {
            # Escape arguments manually in lower versions
            $escapedArgs = switch -regex ($ArgumentList) {
                # Quote paths starting with a drive letter
                '(?<!/D=)[A-Z]:[\\/].*' { $_ -replace '([A-Z]:[\\/].*)', '"$1"'; continue }
                # Do not quote paths if it is NSIS's '/D' argument
                '/D=[A-Z]:[\\/].*' { $_; continue }
                # Quote args with spaces
                ' ' { "`"$_`""; continue }
                default { $_; continue }
            }
            $Process.StartInfo.Arguments = $escapedArgs -join ' '
        }
    }
    try {
        [void]$Process.Start()
    } catch {
        if ($Activity) {
            Write-Host "error." -ForegroundColor DarkRed
        }
        error $_.Exception.Message
        return $false
    }
    if ($redirectToLogFile) {
        # we do this to remove a deadlock potential
        # ref: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput?view=netframework-4.5#remarks
        $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $stderrTask = $Process.StandardError.ReadToEndAsync()
    }
    $Process.WaitForExit()
    if ($redirectToLogFile) {
        Out-UTF8File -FilePath $LogPath -Append -InputObject $stdoutTask.Result
        Out-UTF8File -FilePath $LogPath -Append -InputObject $stderrTask.Result
    }
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
    [void]$proc.Start()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $proc.WaitForExit()

    if($proc.ExitCode -ge 8) {
        debug $stdoutTask.Result
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
        $shimTarget | Convert-Path -ErrorAction SilentlyContinue
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
    Add-Path -Path $abs_shimdir -Global:$global
    if (!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower())"

    # convert to relative path
    $resolved_path = Convert-Path $path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path -Relative $resolved_path
    Pop-Location

    if ($path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        warn_on_overwrite "$shim.shim" $path
        Copy-Item (get_shim_path) "$shim.exe" -Force
        Write-Output "path = `"$resolved_path`"" | Out-UTF8File "$shim.shim"
        if ($arg) {
            Write-Output "args = $arg" | Out-UTF8File "$shim.shim" -Append
        }

        $target_subsystem = Get-PESubsystem $resolved_path
        if ($target_subsystem -eq 2) { # we only want to make shims GUI
            Write-Output "Making $shim.exe a GUI binary."
            Set-PESubsystem "$shim.exe" $target_subsystem | Out-Null
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
            "@pushd $(Split-Path $resolved_path -Parent)",
            "@java -jar `"$resolved_path`" $arg %*",
            "@popd"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  cd `$(wslpath -u '$(Split-Path $resolved_path -Parent)')",
            'else',
            "  cd `$(cygpath -u '$(Split-Path $resolved_path -Parent)')",
            'fi',
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
            '#!/bin/sh',
            "# $resolved_path",
            "python.exe `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } else {
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@bash `"`$(wslpath -u '$resolved_path')`" $arg %* 2>nul",
            '@if %errorlevel% neq 0 (',
            "  @bash `"`$(cygpath -u '$resolved_path')`" $arg %* 2>nul",
            ')'
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            '#!/bin/sh',
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  `"`$(wslpath -u '$resolved_path')`" $arg `"$@`"",
            'else',
            "  `"`$(cygpath -u '$resolved_path')`" $arg `"$@`"",
            'fi'
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    }
}

function get_shim_path() {
    $shim_version = get_config SHIM 'kiennq'
    $shim_path = switch ($shim_version) {
        'scoopcs' { "$(versiondir 'scoop' 'current')\supporting\shims\scoopcs\shim.exe" }
        '71' { "$(versiondir 'scoop' 'current')\supporting\shims\71\shim.exe" }
        'kiennq' { "$(versiondir 'scoop' 'current')\supporting\shims\kiennq\shim.exe" }
        'default' { "$(versiondir 'scoop' 'current')\supporting\shims\scoopcs\shim.exe" }
        default { warn "Unknown shim version: '$shim_version'" }
    }
    return $shim_path
}

function Get-DefaultArchitecture {
    $arch = get_config DEFAULT_ARCHITECTURE
    $system = if (${env:ProgramFiles(Arm)}) {
        'arm64'
    } elseif ([System.Environment]::Is64BitOperatingSystem) {
        '64bit'
    } else {
        '32bit'
    }
    if ($null -eq $arch) {
        $arch = $system
    } else {
        try {
            $arch = Format-ArchitectureString $arch
        } catch {
            warn 'Invalid default architecture configured. Determining default system architecture'
            $arch = $system
        }
    }
    return $arch
}

function Format-ArchitectureString($Architecture) {
    if (!$Architecture) {
        return Get-DefaultArchitecture
    }
    $Architecture = $Architecture.ToString().ToLower()
    switch ($Architecture) {
        { @('64bit', '64', 'x64', 'amd64', 'x86_64', 'x86-64') -contains $_ } { return '64bit' }
        { @('32bit', '32', 'x86', 'i386', '386', 'i686') -contains $_ } { return '32bit' }
        { @('arm64', 'arm', 'aarch64') -contains $_ } { return 'arm64' }
        default { throw [System.ArgumentException] "Invalid architecture: '$Architecture'" }
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
    $Apps | Select-Object -Unique | Where-Object { $_ -ne 'scoop' } | ForEach-Object {
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
    if ($app -match '^(?:(?<bucket>[a-zA-Z0-9-_.]+)/)?(?<app>.*\.json|[a-zA-Z0-9-_.]+)(?:@(?<version>.*))?$') {
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

function is_scoop_outdated() {
    $now = [System.DateTime]::Now
    try {
        $expireHour = (New-TimeSpan (get_config LAST_UPDATE) $now).TotalHours
        return ($expireHour -ge 3)
    } catch {
        # If not System.DateTime
        set_config LAST_UPDATE ($now.ToString('o')) | Out-Null
        return $true
    }
}

function Test-ScoopCoreOnHold() {
    $hold_update_until = get_config HOLD_UPDATE_UNTIL
    if ($null -eq $hold_update_until) {
        return $false
    }
    $parsed_date = New-Object -TypeName DateTime
    if ([System.DateTime]::TryParse($hold_update_until, $null, [System.Globalization.DateTimeStyles]::AssumeLocal, [ref]$parsed_date)) {
        if ((New-TimeSpan $parsed_date).TotalSeconds -lt 0) {
            warn "Skipping self-update of Scoop Core until $($parsed_date.ToLocalTime())..."
            warn "If you want to update Scoop Core immediately, use 'scoop unhold scoop; scoop update'."
            return $true
        } else {
            warn 'Self-update of Scoop Core is enabled again!'
        }
    } else {
        error "'hold_update_until' has been set in the wrong format and was removed."
        error 'If you want to disable self-update of Scoop Core for a moment,'
        error "use 'scoop hold scoop' or 'scoop config hold_update_until <YYYY-MM-DD>/<YYYY/MM/DD>'."
    }
    set_config HOLD_UPDATE_UNTIL $null | Out-Null
    return $false
}

function substitute($entity, [Hashtable] $params, [Bool]$regexEscape = $false) {
    if ($null -ne $entity) {
        $newentity = $entity.PSObject.Copy()
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
                $newentity = $entity | ForEach-Object { , (substitute $_ $params $regexEscape) }
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
    return $env:SCOOP_GH_TOKEN, (get_config GH_TOKEN) | Where-Object -Property Length -Value 0 -GT | Select-Object -First 1
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

# Load Scoop config
$configHome = $env:XDG_CONFIG_HOME, "$env:USERPROFILE\.config" | Select-Object -First 1
$configFile = "$configHome\scoop\config.json"
# Check if it's the expected install path for scoop: <root>/apps/scoop/current
$coreRoot = Split-Path $PSScriptRoot
$pathExpected = ($coreRoot -replace '\\','/') -like '*apps/scoop/current*'
if ($pathExpected) {
    # Portable config is located in root directory:
    #    .\current\scoop\apps\<root>\config.json  <- a reversed path
    # Imagine `<root>/apps/scoop/current/` in a reversed format,
    # and the directory tree:
    #
    # ```
    # <root>:
    # ├─apps
    # ├─buckets
    # ├─cache
    # ├─persist
    # ├─shims
    # ├─config.json
    # ```
    $configPortablePath = Get-AbsolutePath "$coreRoot\..\..\..\config.json"
    if (Test-Path $configPortablePath) {
        $configFile = $configPortablePath
    }
}
$scoopConfig = load_cfg $configFile

# Scoop root directory
$scoopdir = $env:SCOOP, (get_config ROOT_PATH), "$PSScriptRoot\..\..\..\..", "$([System.Environment]::GetFolderPath('UserProfile'))\scoop" | Where-Object { $_ } | Select-Object -First 1 | Get-AbsolutePath

# Scoop global apps directory
$globaldir = $env:SCOOP_GLOBAL, (get_config GLOBAL_PATH), "$([System.Environment]::GetFolderPath('CommonApplicationData'))\scoop" | Where-Object { $_ } | Select-Object -First 1 | Get-AbsolutePath

# Scoop cache directory
# Note: Setting the SCOOP_CACHE environment variable to use a shared directory
#       is experimental and untested. There may be concurrency issues when
#       multiple users write and access cached files at the same time.
#       Use at your own risk.
$cachedir = $env:SCOOP_CACHE, (get_config CACHE_PATH), "$scoopdir\cache" | Where-Object { $_ } | Select-Object -First 1 | Get-AbsolutePath

# Scoop apps' PATH Environment Variable
$scoopPathEnvVar = switch (get_config USE_ISOLATED_PATH) {
    { $_ -is [string] } { $_.ToUpperInvariant() }
    $true { 'SCOOP_PATH' }
    default { 'PATH' }
}

# OS information
$WindowsBuild = [System.Environment]::OSVersion.Version.Build

# Setup proxy globally
setup_proxy
