# versions
function latest_version($app, $url) {
	if($url) { abort "checking version from URL not implemented!" }
	(manifest $app).version
}
function current_version($app) {
	@(versions $app)[-1]
}
function versions($app) {
	sort_versions (gci "$scoopdir\apps\$app" -dir | % { $_.name })
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

function qsort($ary, $fn) {
	if($ary -eq $null) { return @() }
	if(!($ary -is [array])) { return @($ary) }

	$pivot = $ary[0]
	$rem = $ary[1..($ary.length-1)]

	$lesser = qsort ($rem | where { (& $fn $_ $pivot) -lt 0 }) $fn

	$greater = qsort ($rem | where { (& $fn $_ $pivot) -ge 0 }) $fn

	return @() + $lesser + @($pivot) + $greater
}
function sort_versions($versions) {	qsort $versions compare_versions }