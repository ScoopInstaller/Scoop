function 7zip_installed { cmd_available '7z' }

function requires_7zip($manifest, $architecture) {
	foreach($dlurl in @(url $manifest $architecture)) {
		if(file_requires_7zip $dlurl) {	return $true }
	}
}

function file_requires_7zip($fname) {
	$fname -match '\.((gz)|(tar)|(lzma)|(bz2)|(7z)|(rar))$'
}

function extract_7zip($path, $to, $recurse) {
	if(!$recurse) { write-host "extracting..." -nonewline }
	$output = 7z x "$path" -o"$to" -y
	if($lastexitcode -ne 0) { abort "exit code was $lastexitcode" }

	# recursively extract files, e.g. for .tar.gz
	$output | sls '^Extracting\s+(.*)$' | % {
		$fname = $_.matches[0].groups[1].value
		if(file_requires_7zip $fname) { extract_7zip "$to\$fname" $to $true }
	}

	rm $path
	if(!$recurse) { write-host "done" }
}