# The version comparison itself is compiled; see supporting/semver.
if (-not ('Scoop.SemVerComparer' -as [Type])) {
    $semVerDll = "$PSScriptRoot\..\supporting\semver\bin\Scoop.SemVer.dll"
    if (-not (Test-Path -LiteralPath $semVerDll)) {
        throw "Scoop's version comparison requires '$semVerDll'."
    }
    Add-Type -Path $semVerDll
}

function Get-LatestVersion {
    <#
    .SYNOPSIS
        Get latest version of app from manifest
    .PARAMETER AppName
        App's name
    .PARAMETER Bucket
        Bucket which the app belongs to
    .PARAMETER Uri
        Remote app manifest's URI
    #>
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('App')]
        [String]
        $AppName,
        [Parameter(Position = 1)]
        [String]
        $Bucket,
        [Parameter(Position = 2)]
        [String]
        $Uri
    )
    process {
        return (manifest $AppName $Bucket $Uri).version
    }
}

function Select-CurrentVersion { # 'manifest.ps1'
    <#
    .SYNOPSIS
        Select current version of installed app, from 'current\manifest.json' or modified time of version directory
    .PARAMETER AppName
        App's name
    .PARAMETER Global
        Globally installed application
    #>
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('App')]
        [String]
        $AppName,
        [Parameter(Position = 1)]
        [Switch]
        $Global
    )
    process {
        $currentPath = "$(appdir $AppName $Global)\current"
        if (!(get_config NO_JUNCTION)) {
            $manifestPath = "$currentPath\scoop-manifest.json"
            if (!(Test-Path $manifestPath)) { $manifestPath = "$currentPath\manifest.json" }
            $currentVersion = (parse_json $manifestPath).version
            if ($currentVersion -eq 'nightly') {
                $currentVersion = (Get-Item $currentPath).Target | Split-Path -Leaf
            }
        }
        if ($null -eq $currentVersion) {
            $installedVersion = Get-InstalledVersion -AppName $AppName -Global:$Global
            if ($installedVersion) {
                $currentVersion = @($installedVersion)[-1]
            } else {
                $currentVersion = $null
            }
        }
        return $currentVersion
    }
}

function Get-InstalledVersion {
    <#
    .SYNOPSIS
        Get all installed version of app, by checking version directories' 'install.json'
    .PARAMETER AppName
        App's name
    .PARAMETER Global
        Globally installed application
    .NOTES
        Versions are sorted from oldest to newest, i.e., latest installed version is the last one in the output array.
        If no installed version found, empty array will be returned.
    #>
    [OutputType([Object[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [Alias('App')]
        [String]
        $AppName,
        [Parameter(Position = 1)]
        [Switch]
        $Global
    )
    process {
        $appPath = appdir $AppName $Global
        if (Test-Path $appPath) {
            $versions = @((Get-ChildItem "$appPath\*\scoop-install.json", "$appPath\*\install.json" -ErrorAction SilentlyContinue |
                        Sort-Object -Property LastWriteTimeUtc).Directory.Name | Select-Object -Unique)
            return $versions | Where-Object { ($_ -ne 'current') -and ($_ -notlike '_*.old*') }
        } else {
            return @()
        }
    }
    # Deprecated
    # sort_versions (Get-ChildItem $appPath -dir -attr !reparsePoint | Where-Object { $null -ne $(Get-ChildItem $_.FullName) } | ForEach-Object { $_.Name })
}


# Read once per session: scoop runs as a new process per command
function Get-UpdateNightlySetting {
    if ($null -eq $script:UpdateNightly) {
        $script:UpdateNightly = $false
        if (Get-Command get_config -ErrorAction Ignore) {
            $script:UpdateNightly = [bool](get_config UPDATE_NIGHTLY)
        }
    }
    return $script:UpdateNightly
}

# Helper function
function SplitVersion {
    <#
    .SYNOPSIS
        Split version by Delimiter, convert number string to number, and separate letters from numbers
    .PARAMETER Version
        Specifies a version
    .PARAMETER Delimiter
        Specifies the delimiter of version (Literal)
    #>
    [OutputType([Object[]])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [String]
        $Version,
        [String]
        $Delimiter = '-'
    )
    process {
        $Version = $Version -replace '[a-zA-Z]+', "$Delimiter$&$Delimiter"
        return ($Version -split [Regex]::Escape($Delimiter) -ne '' | ForEach-Object { if ($_ -match '^\d+$') { [Long]$_ } else { $_ } })
    }
}

# Deprecated
# Not used anymore in scoop core
function qsort($ary, $fn) {
    warn '"qsort" is deprecated. Please avoid using it anymore.'
    if ($null -eq $ary) { return @() }
    if (!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length - 1)]

    $lesser = qsort ($rem | Where-Object { (& $fn $pivot $_) -lt 0 }) $fn

    $greater = qsort ($rem | Where-Object { (& $fn $pivot $_) -ge 0 }) $fn

    return @() + $lesser + @($pivot) + $greater
}

# Deprecated
# Not used anymore in scoop core
function sort_versions($versions) {
    warn '"sort_versions" is deprecated. Please avoid using it anymore.'
    qsort $versions { param($a, $b) [Scoop.SemVerComparer]::Compare($a, $b) }
}

function compare_versions($a, $b) {
    Show-DeprecatedWarning $MyInvocation 'Compare-Version'
    # Please note the parameters' sequence
    return [Scoop.SemVerComparer]::Compare($b, $a)
}

function latest_version($app, $bucket, $url) {
    Show-DeprecatedWarning $MyInvocation 'Get-LatestVersion'
    return Get-LatestVersion -AppName $app -Bucket $bucket -Uri $url
}

function current_version($app, $global) {
    Show-DeprecatedWarning $MyInvocation 'Select-CurrentVersion'
    return Select-CurrentVersion -AppName $app -Global:$global
}

function versions($app, $global) {
    Show-DeprecatedWarning $MyInvocation 'Get-InstalledVersion'
    return Get-InstalledVersion -AppName $app -Global:$global
}
