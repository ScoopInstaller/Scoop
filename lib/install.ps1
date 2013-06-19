# stuff for dealing with installers
function args($config, $dir) {
	if($config) { return $config | % { (format $_ @{'dir'=$dir}) } }
	@()
}

function run($exe, $arg, $msg) {
	write-host $msg -nonewline
	try {
		$proc = start-process $exe -wait -ea 0 -passthru -arg $arg
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