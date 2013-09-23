function 7zip_installed {
	try { gcm 7z -ea stop } catch { return $false }
	$true
}

function requires_7zip($fname) {
	$fname -match '(\.gz)|(\.tar)|(\.lzma)|(\.bz2)|(\.7z)$'
}

function extract_7zip($path, $to, $recurse) {
	if(!$recurse) { write-host "extracting..." -nonewline }
	$output = 7z x "$path" -o"$to" -y
	if($lastexitcode -ne 0) { abort "exit code was $lastexitcode" }

	# recursively extract files, e.g. for .tar.gz
	$output | sls '^Extracting\s+(.*)$' | % {
		$fname = $_.matches[0].groups[1].value
		if(requires_7zip $fname) { extract_7zip "$to\$fname" $to $true }
	}

	rm $path
	if(!$recurse) { write-host "done" }
}