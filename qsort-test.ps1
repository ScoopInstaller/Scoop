function qsort($ary) {
    if($ary -eq $null) { return @() }
    if(!($ary -is [array])) { return @($ary) }

    $pivot = $ary[0]
    $rem = $ary[1..($ary.length-1)]

    $lesser = qsort ($rem | where { $_ -lt $pivot })
    $greater = qsort ($rem | where { $_ -ge $pivot })

    return @() + $lesser + @($pivot) + $greater
}

function comp_ver($a, $b) {
    if($a -lt $b) { return -1 }
    if($a -gt $b) { return 1 }
    return 0
}


#comp_ver 'a', 1
#$test = "fred,1,6,2,7,9,12,89,45,12,65,1,12,amy".split(',')

$test = "fred,1".split(',')
$sorted = $(qsort $test)
$sorted |% { write-host "'$_'," -no }
write-host ""