# versions
function Get-LatestVersion {
    param (
        [String]
        $App,
        [String]
        $Bucket,
        [String]
        $URL
    )
    return (manifest $App $Bucket $URL).version
}

function Select-CurrentVersion {
    param (
        [String]
        $App,
        [Switch]
        $Global
    )

    $appPath = appdir $App $Global
    if (Test-Path "$appPath\current") {
        $currentVersion = (installed_manifest $App 'current' $Global).version
    } else {
        $currentVersion = (Get-InstalledVersion -App $App -Global:$Global)[-1]
    }
    return $currentVersion
}

function Get-InstalledVersion {
    param (
        [String]
        $App,
        [Switch]
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
    [OutputType('System.Int32')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String]
        $ReferenceVersion,
        [Parameter(Position = 1)]
        [String]
        $DifferenceVersion,
        [String]
        $Delimiter = '-'
    )

    # Trim metadata from version (usually anything after the '+' sign, if we're considering semver)
    # This metadata usually doesn't matter to the end user anyways and is of no value for the comparison.
    # However, we still must be aware of post-release tagging which uses the '+' sign (only seen in Flutter https://flutter.dev/docs/development/tools/sdk/releases).

    # Special usage of '+' for Flutter (https://github.com/flutter/flutter/wiki/Release-process#applying-emergency-fixes)
    $ReferenceVersion = $ReferenceVersion -replace '^([^+]*)\+([^+]*?hotfix.*)$', '$1-$2'
    $DifferenceVersion = $DifferenceVersion -replace '^([^+]*)\+([^+]*?hotfix.*)$', '$1-$2'

    # Trim metadata (https://semver.org/#spec-item-10)
    if ( -join ($ReferenceVersion, $DifferenceVersion) -match '\+') {
        return (Compare-Version ($ReferenceVersion -replace '(.*)\+[0-9A-Za-z.-]+$', '$1') ($DifferenceVersion -replace '(.*)\+[0-9A-Za-z.-]+$', '$1'))
    }
    # Turn back Flutter's '+' for correct comparison
    $ReferenceVersion = $ReferenceVersion -replace '^([^+]*)\-([^+]*?hotfix.*)$', '$1+$2'
    $DifferenceVersion = $DifferenceVersion -replace '^([^+]*)\-([^+]*?hotfix.*)$', '$1+$2'

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
# function qsort($ary, $fn) {
#     if($null -eq $ary) { return @() }
#     if(!($ary -is [array])) { return @($ary) }
#
#     $pivot = $ary[0]
#     $rem = $ary[1..($ary.length-1)]
#
#     $lesser = qsort ($rem | Where-Object { (& $fn $pivot $_) -lt 0 }) $fn
#
#     $greater = qsort ($rem | Where-Object { (& $fn $pivot $_) -ge 0 }) $fn
#
#     return @() + $lesser + @($pivot) + $greater
# }
#
# function sort_versions($versions) { qsort $versions Compare-Version }
