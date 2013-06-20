function qsort($ary, $fn) {
	if($ary -eq $null) { return @() }
	if(!($ary -is [array])) { return @($ary) }

	$pivot = $ary[0]
	$rem = $ary[1..($ary.length-1)]

	$lesser = qsort ($rem | where { (& $fn $_ $pivot) -lt 0 }) $fn

	$greater = qsort ($rem | where { (& $fn $_ $pivot) -ge 0 }) $fn

	return @() + $lesser + @($pivot) + $greater
}

function version($ver) {
	$ver.split('.') | % {
		$num = $_ -as [int]
		if($num) { $num } else { $_ }
	}
}

function compare_versions($a, $b) {
	$ver_a = version $a
	$ver_b = version $b

	for($i=0;$i -lt $ver_a.length;$i++) {
		if($i -gt $ver_b.length) { return 1; }
		if($ver_a[$i] -gt $ver_b[$i]) { return 1; }
		if($ver_a[$i] -lt $ver_b[$i]) { return -1; }
	}
	if($ver_b.length -gt $ver_a.length) { return -1 }
	return 0
}

$test = "10.1.1,4.2.4,4.2.25,4.2,10.1.1.r0-preview,10.1.1.r2-final".split(',')

#split_version '10.1.r0-preview'
compare_versions '4.2.4' '4.2.4.25'
$sorted = qsort $test compare_versions
$sorted |% { write-host "'$_'," -no }
write-host ""