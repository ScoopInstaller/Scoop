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
            # Trying to guess architecture if it's important
            foreach ($asset in $version[0].assets) {
                if ($asset.name -notMatch "linux|macos|osx|arm") {
                    if ($asset.name -match "x64" -and (!$url_64 -or $asset.name -match "win")) {
                        $url_64 = $asset.browser_download_url
                    }
                    if ($asset.name -match "x86" -and (!$url_32 -or $asset.name -match "win")) {
                        $url_32 = $asset.browser_download_url
                    }
                }
            }
            if ($url_64) {
                $manifest.Remove("url")
                $manifest.architecture = @{ "64bit" = @{ "url" = $url_64; "hash" = "" } }
                $manifest.autoupdate = @{ "architecture" = @{ "64bit" = @{ "url" = $url_64.Replace($manifest.version, '$version') } } }
                if ($url_32) {
                    $manifest.architecture["32bit"] = @{ "url" = $url_32; "hash" = "" }
                    $manifest.autoupdate.architecture["32bit"] = @{ "url" = $url_32.Replace($manifest.version, '$version') }
                }
            }
            else {
                $manifest.url = $version[0].assets[0].browser_download_url
                $manifest.autoupdate = $manifest.url.Replace($manifest.version, '$version')
            }
        }
        else {
            $manifest.url = $info.clone_url
        }
    }
    else {
        # Old Code for default (any url) manifest
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

    $manifest | ConvertTo-Json -Depth 4 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) } | out-file -filepath "$name.json" -encoding utf8
    $manifest_path = join-path $pwd "$name.json"
    write-host "Created '$manifest_path'."
}

function new_manifest() {
    [ordered]@{ "homepage" = "";
                "description" = "";
                "license" = "";
                "version" = "";
                "url" = "";
                "hash" = "";
                "extract_dir" = "";
                "bin" = "";
                "depends" = "";
                "checkver" = "";
                "autoupdate" = "" }
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
