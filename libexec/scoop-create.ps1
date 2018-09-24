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
                        "depends" = "";
                        "checkver" = "";
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

    if ($info.license.spdx_id) {
        $manifest.license["identifier"] = $info.license.spdx_id
    } elseif ($info.license) {
        # There should be a better way to get license url (License is not always in LICENSE.* -> 'mpv-player/mpv')
        $license = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/license" | ConvertFrom-Json
        $manifest.license["url"] = $license.download_url
    } else {
        $manifest.license["url"] = ""
    }

    $releases = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/releases" | ConvertFrom-Json
    # If last version is prerelease try to find release and let user choose wich one to use
    if ($releases[0].prerelease -and $releases.count -gt 1) {
        for ($i = 0; $i -lt $releases.count; $i++) {
            if (!$releases[$i].prerelease) {
                $release = $releases[$i]
                break
            }
        }
        if ($release -and (confirm "Want to use prerelease ?")) {
            $release = $releases[0]
        }
    } else {
        $release = $releases[0]
    }

    if ($release.assets) {
        version $release.tag_name

        $architectures = "32bit", "64bit", "32bit / 64bit"
        $architecture = choose_item $architectures "Choose supported architecture"
        switch ($architecture) {
            $architectures[0] { $asset_32 = choose_item $release.assets "Choose 32bit asset" "name" }
            $architectures[1] { $asset_64 = choose_item $release.assets "Choose 64bit asset" "name" }
            $architectures[2] {
                $asset_32 = choose_item $release.assets "Choose 32bit asset ?" "name"
                $asset_64 = choose_item $release.assets "Choose 64bit asset ?" "name"
            }
        }

        url $asset_32.browser_download_url $asset_64.browser_download_url

        if (!(confirm "Download asset(s) to calculate hash")) { return }

        hash $asset_32.browser_download_url $asset_64.browser_download_url

        # Let's hope that there's no extension per architecture apps D:
        $file = if ($asset_64) { $asset_64.name } else { $asset_32.name }
        if ($file -match ".zip" -or (file_requires_7zip $file)) {
            $type = "archive"
        }

        switch ($type) {
            "archive" {
                archive_info
            }
        }
    } else { # If there's no releases try to find tags
        $tags = Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$name/tags" | ConvertFrom-Json
        if ($tags[0]) {
            version $tags[0].name
            if (confirm "64bit only ?") {
                url $null "https://github.com/$owner/$name/archive/$($manifest.version).zip"
            } else {
                url "https://github.com/$owner/$name/archive/$($manifest.version).zip"
            }
            if (confirm "Download asset to calculate hash ?") {
                archive_info
            }
        } else { Write-Host "No tags found" }
    }
}

function archive_info {
    $url = if ($manifest.architecture) { $manifest.architecture["64bit"].url } else { $manifest.url }
    $tmp = "$env:TEMP\scoop"
    Write-Host "Extracting" -NoNewline
    Write-Host "..."
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
    $manifest.version = if ($version[0] -eq 'v') { $version.substring(1) } else { $version }
}

function url($url_32, $url_64) {
    if ($url_64) {
        $manifest.remove("url")
        $manifest.remove("hash")
        $manifest.architecture = @{ "64bit" = @{ "url" = $url_64; "hash" =  "" } }
        $manifest.autoupdate["architecture"] = @{ "64bit" = @{ "url" = $url_64.replace($manifest.version, '$version') } }
        if ($url_32) {
            $manifest.architecture["32bit"] = @{ "url" = $url_32; "hash" = "" }
            $manifest.autoupdate.architecture["32bit"] = @{ "url" = $url_32.replace($manifest.version, '$version') }
        }
    } else {
        $manifest.url = $url_32
        $manifest.autoupdate["url"] = $url_32.replace($manifest.version, '$version')
    }
}

function extract_dir($path) {
    $files = Get-ChildItem -Path $path -File -Name
    if ($files) { return }

    $dirs = Get-ChildItem -Path $path -Directory -Name
    if ($dirs.count -eq 1) {
        $manifest.extract_dir = "$dirs"
        if ($dirs -match $manifest.version) {
            $manifest.autoupdate["extract_dir"] = $dirs.replace($manifest.version, '$version')
        }
    } else { $manifest.remove("extract_dir") }
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

    & $choose
}

if (!$url) {
    scoop help create
}
else {
    create_manifest $url
}

exit 0
