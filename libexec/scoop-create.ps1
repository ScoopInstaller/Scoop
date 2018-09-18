# Usage: scoop create <url>
# Summary: Create a custom app manifest
# Help: Create your own custom app manifest
param($url)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\install.ps1"

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
        # There's should be a way do get license url (License is not always in LICENSE.* file)
        $license = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/license") | ConvertFrom-Json
        $manifest.license["url"] = $license.download_url
    } else {
        $manifest.license["url"] = ""
    }

    $releases = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/releases") | ConvertFrom-Json
    # If last version is prerelease try to find release and let user choose wich one to use
    if ($releases[0].prerelease -and $releases.length -gt 1) {
        for ($i = 0; $i -lt $releases.length; $i++) {
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
        $windows_ext = ".(zip|rar|7z|msi|exe)"
        $prefered_ext = ".(zip|7z|rar)"

        $manifest.version = $release.tag_name

        foreach ($asset in $release.assets) {
            if ($asset.name -match $windows_ext) {
                if ($asset.name -match "x64" -and (!$asset_64 -or $asset.name -match $prefered_ext)) {
                    $asset_64 = $asset
                }
                if ($asset.name -match "x86" -and (!$asset_32 -or $asset.name -match $prefered_ext)) {
                    $asset_32 = $asset
                }
            }
        }

        if (!($asset_32 -or $asset_64)) {
            if ($release.assets.length -gt 1) {
                $asset_32 = choose_item $release.assets $null "name"
            } else {
                $asset_32 = $release.assets[0]
            }
        }

        url $asset_32.browser_download_url $asset_64.browser_download_url

        if ($asset_64) {
            if (confirm "Download $($asset_64.name) to calculate hash ?") {
                install_info $asset_64.browser_download_url "64bit"
            }
        }

        if ($asset_32) {
            if (confirm "Download $($asset_32.name) to calculate hash ?") {
                install_info $asset_32.browser_download_url "32bit"
            }
        }

    } else { # If there's no releases try to find tags
        $tags = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/tags") | ConvertFrom-Json
        if ($tags[0]) {
            $manifest.version = $tags[0].name
            url "https://github.com/$owner/$name/archive/$($manifest.version).zip"
            if (confirm "Download $($manifest.version) to calculate hash ?") {
                install_info $manifest.url
            }
        }
    }

}

function install_info($url, $architecture) {
    if ($architecture -eq "64bit" -or $manifest.architecture) {
        $manifest.architecture[$architecture].hash = get_hash_for_app $name $null $manifest.version $url
    } else {
        $manifest.hash = get_hash_for_app $name $null $manifest.version $url
    }
    $tmp = "$pwd\_tmp"
    unzip (cache_path $name $manifest.version $url) $tmp
    extract_dir $tmp
    bin $tmp
    Remove-Item $tmp -Force -Recurse
}

function url($32bit, $64bit) {
    if ($64bit) {
        $manifest.remove("url")
        $manifest.remove("hash")
        $manifest.architecture = @{ "64bit" = @{ "url" = $64bit; "hash" =  "" } }
        $manifest.autoupdate["architecture"] = @{ "64bit" = @{ "url" = $64bit.replace($manifest.version, '$version') } }
        if ($32bit) {
            $manifest.architecture["32bit"] = @{ "url" = $asset_32.browser_download_url; "hash" = "" }
            $manifest.autoupdate.architecture["32bit"] = @{ "url" = $32bit.replace($manifest.version, '$version') }
        }
    } else {
        $manifest.url = $32bit
        $manifest.autoupdate["url"] = $32bit.replace($manifest.version, '$version')
    }
}

function extract_dir($path) {
    $dir = Get-ChildItem -Path $path -Directory -Name
    if ($dir.count -eq 1) {
        $manifest.extract_dir = "$dir"
        if ($dir -match $manifest.version) {
            $manifest.autoupdate["extract_dir"] = $dir.replace($manifest.version, '$version')
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

    if ((Compare-Object $bin $manifest.bin).length -ne 0) {
        $manifest.bin += $bin
        $manifest.bin = $manifest.bin | Sort-Object | Get-Unique
    } else {
        $manifest.bin = $bin
    }
}

function file_name($segment) {
    $segment.substring(0, $segment.lastIndexOf('.'))
}

function confirm($quote, $command) {
    $answer = Read-Host $quote "(y/N)"
    return $answer.toLower() -eq 'y'
}

function parse_url($url) {
    $uri = new-object Uri $url
    $uri.pathandquery.substring(1).split("/")
}

function choose_item($list, $quote, $property) {
    for ($i = 0; $i -lt $list.length; $i++) {
        $item = $list[$i]
        if ($property) {
            $item = $item | Select-Object -ExpandProperty $property
        }
        Write-Host "[$($i + 1)]: $item"
    }

    $choose =  {
        $selection = if ($quote) {Read-Host $quote} else {Read-Host}
        if ($selection -match "\d+" -and ($selection - 1) -lt $list.length) {
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
