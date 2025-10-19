### Hash-related functions

function hash_for_url($manifest, $url, $arch) {
    $hashes = @(hash $manifest $arch) | Where-Object { $_ -ne $null }

    if ($hashes.length -eq 0) { return $null }

    $urls = @(script:url $manifest $arch)

    $index = [array]::IndexOf($urls, $url)
    if ($index -eq -1) { abort "Couldn't find hash in manifest for '$url'." }

    @($hashes)[$index]
}

function get_hash([String] $multihash) {
    $type, $hash = $multihash -split ':'
    if (!$hash) {
        # no type specified, assume sha256
        $type, $hash = 'sha256', $multihash
    }

    if (@('md5', 'sha1', 'sha256', 'sha512') -notcontains $type) {
        return $null, "Hash type '$type' isn't supported."
    }

    return $type, $hash.ToLower()
}
