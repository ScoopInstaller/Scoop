# Usage: scoop create <url>
# Summary: Create a custom app manifest
# Help: Create your own custom app manifest
param($url)

. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\decompress.ps1"

$manifest = [ordered]@{ "homepage" = "";
                        "description" = "";
                        "license" = @{};
                        "version" = "";
                        "url" = "";
                        "hash" = "";
                        "extract_dir" = "";
                        "bin" = @();
                        "checkver" = "";
                        "depends" = "";
                        "autoupdate" = @{} }

function create_manifest($url) {
    try {
        $url_parts = parse_url $url
    } catch {
        abort "Error: $url is not a valid URL"
    }

    if ($url.startsWith("https://github.com/")) {
        github
        $name = $url_parts[1]
    } else {
        # Old Code for default (any url) manifest
        $manifest.url = $url
        $name = choose_item $url_parts "App Name"
        $name = if ($name.Length -gt 0) {
            $name
        } else {
            file_name ($url_parts | Select-Object -last 1)
        }
        $manifest.version = choose_item $url_parts
    }

    $manifest | ConvertToPrettyJson | Out-File -filepath "$name.json" -encoding utf8
    $manifest_path = Join-Path $pwd "$name.json"
    Write-Host "Created '$manifest_path'."
}

function github {
    $owner = $url_parts[0]
    $name = $url_parts[1]

    $info = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name") | ConvertFrom-Json

    $manifest.homepage = if ($info.homepage) {$info.homepage} else {$info.html_url}
    $manifest.description = $info.description
    $manifest.checkver = @{ github = $info.html_url }

    # License with key = "other" now gets spdx_id = "NOASSERTION" instead of null? Url stays as null, workaround for now :/
    if ($info.license -and $info.license.url) {
        $manifest.license["identifier"] = $info.license.spdx_id
    } elseif ($info.license) {
        # There should be a better way to get license url (License is not always in LICENSE.* -> 'mpv-player/mpv')
        $license = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/license" | ConvertFrom-Json
        $manifest.license["url"] = $license.download_url
    } else {
        $manifest.license["url"] = ""
    }

    $releases = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/releases" | ConvertFrom-Json

    if ($releases) {
        $release = choose_item $releases "Choose version" "tag_name"
        # Version value for release and tag stored in different properties, we don't store actual value in manifest.version, so we store it here just in case.
        $version = $release.tag_name
        version $version
    } else {
        $tags = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/tags" | ConvertFrom-Json
        $release = choose_item $tags "Choose version" "name"
        $version = $release.name
        version $version
    }

    $architectures = "32bit", "64bit", "32bit / 64bit"
    $architecture = choose_item $architectures "Choose supported architecture"

    if ($release.assets) {
        switch ($architecture) {
            $architectures[0] { $url_32 = (choose_item $release.assets "Choose 32bit asset" "name").browser_download_url }
            $architectures[1] { $url_64 = (choose_item $release.assets "Choose 64bit asset" "name").browser_download_url }
            $architectures[2] {
                $url_32 = (choose_item $release.assets "Choose 32bit asset" "name").browser_download_url
                $url_64 = (choose_item $release.assets "Choose 64bit asset" "name").browser_download_url
            }
        }
    } else {
        switch ($architecture) {
            $architectures[0] { $url_32 = "https://github.com/$owner/$name/archive/$version.zip" }
            $architectures[1] { $url_64 = "https://github.com/$owner/$name/archive/$version.zip" }
        }
    }

    url $url_32 $url_64

    if (!(confirm "Download asset(s) to calculate hash")) { return }

    hash $url_32 $url_64

    $file = if ($url_64) { $url_64 } else { $url_32 }
    if ($file.endsWith(".zip") -or (file_requires_7zip $file)) {
        $type = "archive"
    }

    switch ($type) {
        "archive" {
            archive_info
        }
    }
}

function archive_info {
    $url = if ($manifest.architecture) { $manifest.architecture["64bit"].url } else { $manifest.url }
    $tmp = "$env:TEMP\scoop"
    Write-Host "Extracting..."
    extract_7zip (cache_path $name $manifest.version $url) $tmp
    extract_dir $tmp
    bin $tmp
    Remove-Item $tmp -Force -Recurse
}

function hash($url_32, $url_64) {
    if ($url_64) {
        $manifest.architecture["64bit"].hash = get_hash_for_app $name $null $manifest.version $url_64
        if ($url_32) {
            $manifest.architecture["32bit"].hash = get_hash_for_app $name $null $manifest.version $url_32
        }
    } else {
        $manifest.hash = get_hash_for_app $name $null $manifest.version $url_32
    }
}

function version($version) {
    $manifest.version = if ($version.startsWith('v')) { $version.substring(1) } else { $version }
}

function replace_version($url) {
    $versionVariables = @{
        '$version' = $manifest.version;
        '$underscoreVersion' = ($manifest.version -replace "\.", "_");
        '$dashVersion' = ($manifest.version -replace "\.", "-");
        '$cleanVersion' = ($manifest.version -replace "\.", "");
    }

    foreach($pair in $versionVariables.GetEnumerator()) {
        $url = $url -replace $pair.value, $pair.name
    }

    return $url
}

function url($url_32, $url_64) {
    if ($url_64) {
        $manifest.remove("url")
        $manifest.remove("hash")
        $manifest.architecture = @{ "64bit" = @{ "url" = $url_64; "hash" =  "" } }
        $manifest.autoupdate["architecture"] = @{ "64bit" = @{ "url" = (replace_version $url_64) } }
        if ($url_32) {
            $manifest.architecture["32bit"] = @{ "url" = $url_32; "hash" = "" }
            $manifest.autoupdate.architecture["32bit"] = @{ "url" = (replace_version $url_32) }
        }
    } else {
        $manifest.url = $url_32
        $manifest.autoupdate["url"] = (replace_version $url_32)
    }
}

function extract_dir($path) {
    $files = Get-ChildItem -Path $path -File -Name
    if ($files) { return }

    $dirs = Get-ChildItem -Path $path -Directory -Name
    if ($dirs.count -eq 1) {
        $manifest.extract_dir = "$dirs"
        if ($dirs -match $manifest.version) {
            $manifest.autoupdate["extract_dir"] = (replace_version $manifest.extract_dir)
        }
    }
}

function bin($path) {
    $bin_ext = @("*.exe", "*.bat")
    $bin = Get-ChildItem -Path $path -File -Include $bin_ext -Recurse

    if ($manifest.extract_dir) {
        $bin = $bin -Replace [Regex]::Escape("$path\$($manifest.extract_dir)\")
    } else {
        $bin = $bin -Replace [Regex]::Escape("$path\")
    }

    $manifest.bin = $bin
}

function file_name($segment) {
    $segment.substring(0, $segment.lastIndexOf('.'))
}

function confirm($quote, $command) {
    Write-Host $quote -NoNewline -ForegroundColor DarkYellow
    Write-Host " (y/N)" -ForegroundColor Green
    $answer = Read-Host
    return $answer.toLower() -eq 'y'
}

function parse_url($url) {
    $uri = new-object Uri $url
    $uri.pathandquery.substring(1).split('/')
}

function choose_item($list, $quote, $property) {
    if ($list.count -eq 1) { return $list }

    for ($i = 0; $i -lt $list.count; $i++) {
        $item = $list[$i]
        if ($property) {
            $item = $item | Select-Object -ExpandProperty $property
        }
        Write-Host "[$($i + 1)]: " -NoNewline -ForegroundColor Green
        Write-Host $item -ForegroundColor DarkYellow
    }

    $choose =  {
        $selection = if ($quote) { Read-Host $quote } else { Read-Host }
        if ($selection -match "\d+" -and ($selection - 1) -lt $list.count) {
            return $list[$selection - 1]
        } else {
            Write-Host "Out of bound. Try again..."
            & $choose
        }
    }
    & $choose;
}

if (!$url) {
    scoop help create
}
else {
    create_manifest $url
}

exit 0
