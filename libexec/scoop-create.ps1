# Usage: scoop create <url>
# Summary: Create a custom app manifest
# Help: Create your own custom app manifest
param($url)

function create_manifest($url) {
    try {
        $url_parts = parse_url $url
    }
    catch {
        abort "Error: $url is not a valid URL"
    }

    $manifest = new_manifest

    if ($url.StartsWith("https://github.com/")) {
        $owner = $url_parts[0]
        $name = $url_parts[1]
        # Getting Info
        $info = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name") | ConvertFrom-Json
        $version = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/releases") | ConvertFrom-Json
        # In case if user url was junky
        if ($info.homepage) {
            $manifest.homepage = $info.homepage
        }
        else {
            $manifest.homepage = $info.html_url
        }
        $manifest.description = $info.description
        if ($info.license) {
            $manifest.license = $info.license.name
        }
        else {
            $manifest.Remove('license')
        }
        $manifest.version = $version[0].tag_name
        $manifest.checkver = @{ github = $info.html_url }
        if ($version[0].assets) {
            $manifest.url = $version.assets[0].browser_download_url
            $manifest.autoupdate = @{ "url" = $manifest.url.Replace($manifest.version, '$version')}
        }
        else {
            $manifest.url = $info.clone_url
        }
    }
    else {
        $manifest.url = $url
        $name = choose_item $url_parts "App name"
        $name = if ($name.Length -gt 0) {
            $name
        }
        else {
        file_name ($url_parts | select-object -last 1)
        }
        $manifest.version = choose_item $url_parts "Version"
    }

    $manifest | convertto-json | out-file -filepath "$name.json" -encoding utf8
    $manifest_path = join-path $pwd "$name.json"
    write-host "Created '$manifest_path'."
}

function new_manifest() {
    @{ "homepage" = ""; "license" = ""; "version" = ""; "url" = "";
        "hash" = ""; "extract_dir" = ""; "bin" = ""; "depends" = "" }
}

function file_name($segment) {
    $segment.substring(0, $segment.lastindexof('.'))
}

function parse_url($url) {
    $uri = new-object Uri $url
    $uri.pathandquery.substring(1).split("/")
}

function choose_item($list, $query) {
    for ($i = 0; $i -lt $list.count; $i++) {
        $item = $list[$i]
        write-host "$($i + 1)) $item"
    }
    $sel = read-host $query

    if ($sel.trim() -match '^[0-9+]$') {
        return $list[$sel-1]
    }

    $sel
}

if (!$url) {
    scoop help create
}
else {
    create_manifest $url
}

exit 0
