if (-not ('Scoop.VersionComparer' -as [Type])) {
    $semVerDll = "$PSScriptRoot\..\supporting\version\bin\Scoop.VersionComparer.dll"
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

<#
    .SYNOPSIS
        Select the version of an installed app that is currently in use
    .PARAMETER AppName
        App's name
    .PARAMETER Global
        Globally installed application
#>
function Select-CurrentVersion { # 'manifest.ps1'
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

