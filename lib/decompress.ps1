function 7zip_installed { cmd_available '7z' }

function requires_7zip($manifest, $architecture) {
    foreach($dlurl in @(url $manifest $architecture)) {
        if(file_requires_7zip $dlurl) { return $true }
    }
}

function requires_lessmsi ($manifest, $architecture) {
    $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
    if (!$useLessMsi) { return $false }

    $(url $manifest $architecture |? {
        $_ -match '\.(msi)$'
    } | measure | select -exp count) -gt 0
}

function file_requires_7zip($fname) {
    $fname -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(7z)|(rar)|(iso)|(xz))$'
}

function extract_7zip($path, $to, $recurse) {
    $output = 7z x "$path" -o"$to" -y
    if($lastexitcode -ne 0) { abort "exit code was $lastexitcode" }

    # check for tar
    $tar = (split-path $path -leaf) -replace '\.[^\.]*$', ''
    if($tar -match '\.tar$') {
        if(test-path "$to\$tar") { extract_7zip "$to\$tar" $to $true }
    }

    if($recurse) { rm $path } # clean up intermediate files
}
