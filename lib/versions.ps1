# versions
function Get-LatestVersion {
    <#
    .SYNOPSIS
        Get latest version of app
    .DESCRIPTION
        Get latest version of app from manifest
    #>
    param (
        [String]
        # App's name
        $App,
        [String]
        # Bucket which the app is belong to
        $Bucket,
        [String]
        # Remote app manifest's URI
        $URL
    )
    return (manifest $App $Bucket $URL).version
}

function Select-CurrentVersion {
    <#
    .SYNOPSIS
        Select current version of app
    .DESCRIPTION
        Select current version of installed app, from 'current\manifest.json' or modified time of version directory
    #>
    param (
        [String]
        # App's name
        $App,
        [Switch]
        # If global installed
        $Global
    )

    $appPath = appdir $App $Global
    if (Test-Path "$appPath\current") {
        $currentVersion = (installed_manifest $App 'current' $Global).version
    } else {
        $installedVersion = Get-InstalledVersion -App $App -Global:$Global
        if ($installedVersion) {
            $currentVersion = $installedVersion[-1]
        } else {
            $currentVersion = $null
        }
    }
    return $currentVersion
}

function Get-InstalledVersion {
    <#
    .SYNOPSIS
        Get installed version of app
    .DESCRIPTION
        Get all installed version of app, by checking version directories' 'install.json'
    #>
    param (
        [String]
        # App's name
        $App,
        [Switch]
        # If global installed
        $Global
    )

    $appPath = appdir $App $Global
    if (!(Test-Path $appPath)) {
        return @()
    } else {
        return @((Get-ChildItem "$appPath\*\install.json" | Sort-Object -Property LastWriteTimeUtc).Directory.Name) -ne 'current'
    }

    # Deprecated
    # sort_versions (Get-ChildItem $appPath -dir -attr !reparsePoint | Where-Object { $null -ne $(Get-ChildItem $_.FullName) } | ForEach-Object { $_.Name })
}

function Compare-Version {
    <#
    .SYNOPSIS
        Compare versions
    .DESCRIPTION
        Compare versions, mainly according to SemVer's rules
    .OUTPUTS
        System.Int32
            '0' if DifferenceVersion is equal to ReferenceVersion,
            '1' if DifferenceVersion is greater then ReferenceVersion,
            '-1' if DifferenceVersion is less then ReferenceVersion
    #>
    [OutputType([Int])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String]
        # Specifies a version used as a reference for comparison.
        $ReferenceVersion,
        [Parameter(Position = 1)]
        [String]
        # Specifies the version that are compared to the reference version.
        $DifferenceVersion,
        [String]
        # Specifies the delimiter of versions
        $Delimiter = '-'
    )

    # Use '+' sign as post-release, see https://github.com/lukesampson/scoop/pull/3721#issuecomment-553718093
    $ReferenceVersion = $ReferenceVersion -replace '\+', '-'
    $DifferenceVersion = $DifferenceVersion -replace '\+', '-'

    if ($DifferenceVersion -eq $ReferenceVersion) {
        return 0
    }

    $splitReferenceVersion = @($ReferenceVersion -split $Delimiter | ForEach-Object { if ($_ -match "^\d+$") { [Long]$_ } else { ($_ -replace '[a-zA-Z]+', '.$&.').Replace('..', '.').Trim('.') } })
    $splitDifferenceVersion = @($DifferenceVersion -split $Delimiter | ForEach-Object { if ($_ -match "^\d+$") { [Long]$_ } else { ($_ -replace '[a-zA-Z]+', '.$&.').Replace('..', '.').Trim('.') } })

    if ($splitReferenceVersion[0] -eq 'nightly' -and $splitDifferenceVersion[0] -eq 'nightly') {
        return 0
    }

    for ($i = 0; $i -lt [Math]::Max($splitReferenceVersion.Length, $splitDifferenceVersion.Length); $i++) {
        if ($i -ge $splitReferenceVersion.Length) {
            if ($splitDifferenceVersion[$i] -match "alpha|beta|rc|pre") {
                return -1
            } else {
                return 1
            }
        }
        if ($i -ge $splitDifferenceVersion.Length) {
            if ($splitReferenceVersion[$i] -match "alpha|beta|rc|pre") {
                return 1
            } else {
                return -1
            }
        }

        if (($splitReferenceVersion[$i] -match "\.") -or ($splitDifferenceVersion[$i] -match "\.")) {
            $Result = Compare-Version $splitReferenceVersion[$i] $splitDifferenceVersion[$i] -Delimiter '\.'
            if ($Result -ne 0) {
                return $Result
            } else {
                continue
            }
        }

        if ($null -ne $splitReferenceVersion[$i] -and $null -ne $splitDifferenceVersion[$i]) {
            # don't try to compare int to string
            if ($splitReferenceVersion[$i] -is [string] -and $splitDifferenceVersion[$i] -isnot [string]) {
                $splitDifferenceVersion[$i] = "$($splitDifferenceVersion[$i])"
            }
            if ($splitDifferenceVersion[$i] -is [string] -and $splitReferenceVersion[$i] -isnot [string]) {
                $splitReferenceVersion[$i] = "$($splitReferenceVersion[$i])"
            }
        }

        if ($splitDifferenceVersion[$i] -gt $splitReferenceVersion[$i]) { return 1 }
        if ($splitDifferenceVersion[$i] -lt $splitReferenceVersion[$i]) { return -1 }
    }

    return 0
}

# Deprecated
# Not used anymore in scoop core
function qsort($ary, $fn) {
    warn '"qsort" is deprecated. Please avoid using it anymore.'
    if($null -eq $ary) { return @() }
    if(!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length-1)]

    $lesser = qsort ($rem | Where-Object { (& $fn $pivot $_) -lt 0 }) $fn

    $greater = qsort ($rem | Where-Object { (& $fn $pivot $_) -ge 0 }) $fn

    return @() + $lesser + @($pivot) + $greater
}

# Deprecated
# Not used anymore in scoop core
function sort_versions($versions) {
    warn '"sort_versions" is deprecated. Please avoid using it anymore.'
    qsort $versions Compare-Version
}
