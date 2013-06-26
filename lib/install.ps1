function cache_path($app, $version, $url) {
	"$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')"
}

function dl_with_cache($app, $version, $url, $to) {
	$cached = full_path (cache_path $app $version $url)
	if(!(test-path $cached)) {
		$null = ensure $cachedir
		echo "downloading $url..."
		dl $url $cached
	} else { echo "loading $url from cache..."}
	cp $cached $to
}

# hashes
function hash_for_url($manifest, $url, $arch) {
	$hashes = @(hash $manifest $arch) | ? { $_ -ne $null };
	if($hashes.length -eq 0) { return $null }

	$urls = @(url $manifest $arch)

	$index = [array]::indexof($urls, $url)
	if($index -eq -1) { abort "couldn't find hash in manifest for $url" }

	$hashes[$index]
}

function check_hash($file, $url, $manifest, $arch) {
	$hash = hash_for_url $manifest $url $arch
	if(!$hash) {
		warn "warning: no hash in manifest. sha256 is:`n$(compute_hash (full_path $file) 'sha256')"
		return
	}

	write-host "checking hash..." -nonewline
	$expected = $null; $actual = $null;
	if($hash.md5) {
		$expected = $hash.md5; $actual = compute_hash (full_path $file) 'md5'
	} elseif($hash.sha1){
		$expected = $hash.sha1; $actual = compute_hash (full_path $file) 'sha1'
	} elseif($hash.sha256){
		$expected = $hash.sha256; $actual = compute_hash (full_path $file) 'sha256'
	} else {
		$type = $hash | gm -membertype noteproperty | % { $_.name }
		abort "hash type $type isn't supported"		
	}

	if($actual -ne $expected) {
		abort "hash check failed for $url. expected: $($expected), actual: $($actual)!"
	}
	write-host "ok"
}

function compute_hash($file, $algname) {
	$alg = [system.security.cryptography.hashalgorithm]::create($algname)
	$fs = [system.io.file]::openread($file)
	try {
		$hexbytes = $alg.computehash($fs) | % { $_.tostring('x2') }
		[string]::join('', $hexbytes)
	} finally {
		$fs.dispose()
		$alg.dispose()
	}
}

# for dealing with installers
function args($config, $dir) {
	if($config) { return $config | % { (format $_ @{'dir'=$dir}) } }
	@()
}

function run($exe, $arg, $msg, $continue_exit_codes) {
	write-host $msg -nonewline
	try {
		$proc = start-process $exe -wait -ea stop -passthru -arg $arg
		if($proc.exitcode -ne 0) {
			if($continue_exit_codes -and ($continue_exit_codes.containskey($proc.exitcode))) {
				warn $continue_exit_codes[$proc.exitcode]
				return $true
			}
			write-host "exit code was $($proc.exitcode)"; return $false
		}
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