# for dealing with installers
function args($config, $dir) {
	if($config) { return $config | % { (format $_ @{'dir'=$dir}) } }
	@()
}

function run($exe, $arg, $msg) {
	write-host $msg -nonewline
	try {
		$proc = start-process $exe -wait -ea stop -passthru -arg $arg
		if($proc.exitcode -ne 0) { write-host "exit code was $($proc.exitcode)"; return $false }
	} catch {
		write-host -f red $_.exception.tostring()
		return $false
	}
	write-host "done"
	return $true
}

function is_in_dir($dir, $file) {
	$file = "$(full_path $file)"
	$dir = "$(full_path $dir)"
	$file -match "^$([regex]::escape("$dir\"))"
}


# versions
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