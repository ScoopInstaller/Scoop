function 7zip_installed {
    try { gcm 7z -ea 0 } catch { return $false }
    $true
}

function requires_7zip($fname) {
    $fname -match '(\.gz)|(\.tar)|(\.lzma)$'
}

function extract_7zip($path) {
    write-host "extracting $(split-path $path -leaf)..."
    $dir = split-path $path
    $output = 7z x "$path" -o"$dir"
    if($lastexitcode -ne 0) { abort "exit code was $lastexitcode" }

    # recursively extract files, e.g. for .tar.gz
    $output | sls '^Extracting\s+(.*)$' | % {
        $fname = $_.matches[0].groups[1].value
        if(requires_7zip $fname) { extract_7zip "$dir\$fname"}
    }

    rm $path
}