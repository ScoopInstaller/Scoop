function qsort($ary) {
    if($ary -eq $null) { return @() }
    if(!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length-1)]

    $lesser = qsort ($rem | where { $_ -lt $pivot })
    $greater = qsort ( $rem | where { $_ -ge $pivot })

    return @() + $lesser + @($pivot) + $greater
}

$test = "fred,1,6,2,7,9,12,89,45,12,65,1,12,amy".split(',')
$sorted = $(qsort $test)
#"result: $sorted"
$sorted |% { "el: $_" }