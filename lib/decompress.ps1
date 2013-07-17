function 7zip_installed {
    try { gcm 7z -ea 0 } catch { return $false }
    $true
}

function requires_7zip($fname) {
    $fname -match '(\.gz)|(\.tar)|(\.lzma)$'
}

function extract_7zip($path) {
    $dir = split-path $path
    & 7z x "$path" -o"$dir"
    write-host "exit code: $lastexitcode"
}