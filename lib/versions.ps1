# versions
function latest_version($app, $bucket, $url) {
    (manifest $app $bucket $url).version
}
function current_version($app, $global) {
    @(versions $app $global)[-1]
}
function versions($app, $global) {
    $appdir = appdir $app $global
    if(!(test-path $appdir)) { return @() }

    sort_versions (Get-ChildItem $appdir -dir -attr !reparsePoint | Where-Object { $null -ne $(Get-ChildItem $_.fullname) } | ForEach-Object { $_.name })
}

function Compare-Version {
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

    if ($DifferenceVersion -eq $ReferenceVersion) {
        return 0
    }

    $SplitReferenceVersion = @($ReferenceVersion -split $Delimiter | ForEach-Object { if ($_ -match "^\d+$") { [int]$_ } else { $_ } })
    $SplitDifferenceVersion = @($DifferenceVersion -split $Delimiter | ForEach-Object { if ($_ -match "^\d+$") { [int]$_ } else { $_ } })

    for ($i = 0; $i -lt [Math]::Max($ReferenceVersion.Length, $DifferenceVersion.Length); $i++) {
        if ($i -gt $ReferenceVersion.Length) {
            return 1
        }
        if ($SplitReferenceVersion[$i] -match '\.' -or $SplitDifferenceVersion[$i] -match '\.') {
            $Result = Compare-Version $SplitReferenceVersion[$i] $SplitDifferenceVersion[$i] -Delimiter '\.'
            if ($Result -ne 0) {
                return $Result
            } else {
                continue
            }
        }

        # don't try to compare int to string
        if ($SplitReferenceVersion[$i] -is [string] -and $SplitDifferenceVersion[$i] -isnot [string]) {
            $SplitDifferenceVersion[$i] = "$($SplitDifferenceVersion[$i])"
        }

        if ($SplitDifferenceVersion[$i] -gt $SplitReferenceVersion[$i]) { return 1 }
        if ($SplitDifferenceVersion[$i] -lt $SplitReferenceVersion[$i]) { return -1 }
    }

    return 0
}

function qsort($ary, $fn) {
    if($null -eq $ary) { return @() }
    if(!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length-1)]

    $lesser = qsort ($rem | Where-Object { (& $fn $pivot $_) -lt 0 }) $fn

    $greater = qsort ($rem | Where-Object { (& $fn $pivot $_) -ge 0 }) $fn

    return @() + $lesser + @($pivot) + $greater
}
function sort_versions($versions) { qsort $versions Compare-Version }
