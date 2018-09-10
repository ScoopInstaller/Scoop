# Usage: scoop create <url>
# Summary: Create a custom app manifest
# Help: Create your own custom app manifest
param($url)

. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\install.ps1"

$manifest = [ordered]@{ "homepage" = "";
                        "description" = "";
                        "license" = @{};
                        "version" = "";
                        "url" = "";
                        "hash" = "";
                        "extract_dir" = "";
                        "bin" = "";
                        "depends" = "";
                        "checkver" = "";
                        "autoupdate" = @{} }

function create_manifest($url) {
    try {
        $url_parts = parse_url $url
    } catch {
        abort "Error: $url is not a valid URL"
    }

    if ($url.StartsWith("https://github.com/")) {
        github
        $name = $url_parts[1]
    } else {
        # Old Code for default (any url) manifest
        $manifest.url = $url
        $name = choose_item $url_parts "App name"
        $name = if ($name.Length -gt 0) {
            $name
        } else {
            file_name ($url_parts | select-object -last 1)
        }
        $manifest.version = choose_item $url_parts "Version"
    }

    $manifest | ConvertToPrettyJson | out-file -filepath "$name.json" -encoding utf8
    $manifest_path = join-path $pwd "$name.json"
    write-host "Created '$manifest_path'."
}

function github {
    $owner = $url_parts[0]
    $name = $url_parts[1]

    $info = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name") | ConvertFrom-Json

    if ($info.homepage) {
        $manifest.homepage = $info.homepage
    } else {
        $manifest.homepage = $info.html_url
    }

    $manifest.description = $info.description

    if ($info.license) {
        if ($info.license -match "Other") {
            $manifest.license["url"] = "https://raw.githubusercontent.com/" + $info.full_name + "/" + $info.default_branch + "/LICENSE.txt"
        } else {
            $manifest.license["identifier"] = $licenses[$info.license.name]
        }
    } else {
        $manifest.Remove('license')
    }

    $manifest.checkver = @{ github = $info.html_url }

    $releases = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/releases") | ConvertFrom-Json
    if ($releases[0].assets) {
        $manifest.version = $releases[0].tag_name
        # Trying to guess architecture if it's important
        foreach ($asset in $releases[0].assets) {
            if ($asset.name -match ".(zip|rar|7z|msi|exe)") {
                if ($asset.name -match "x64" -and (!$release_64 -or $asset.name -match ".(zip|7z|rar)")) {
                    $release_64 = $asset
                }
                if ($asset.name -match "x86" -and (!$release_32 -or $asset.name -match ".(zip|7z|rar)")) {
                    $release_32 = $asset
                }
            }
        }
        if ($release_64) {
            $manifest.Remove("url")
            $manifest.Remove("hash")
            $manifest.architecture = @{ "64bit" = @{ "url" = $release_64.browser_download_url; "hash" = "" } }
            $manifest.architecture["64bit"].hash = calculate_hash $release_64.name $release_64.browser_download_url
            $manifest.autoupdate["architecture"] = @{ "64bit" = @{ "url" = $release_64.browser_download_url.Replace($manifest.version, '$version') } }
            if ($release_32) {
                $manifest.architecture["32bit"] = @{ "url" = $release_32.browser_download_url; "hash" = "" }
                $manifest.architecture["32bit"].hash = calculate_hash $release_32.name $release_32.browser_download_url
                $manifest.autoupdate.architecture["32bit"] = @{ "url" = $release_32.browser_download_url.Replace($manifest.version, '$version') }
            }
        } else {
            $manifest.url = $releases[0].assets[0].browser_download_url
            $manifest.autoupdate["url"] = $manifest.url.Replace($manifest.version, '$version')
            $manifest.hash = calculate_hash $releases[0].assets[0].name $manifest.url
        }
    } else {
        # If there's no releases try to find tags
        $tags = Invoke-WebRequest -Uri ("https://api.github.com/repos/$owner/$name/tags") | ConvertFrom-Json
        if ($tags[0]) {
            $manifest.version = $tags[0].name
            $manifest.url = "https://github.com/$owner/$name/archive/" + $manifest.version + ".zip"
            $manifest.hash = calculate_hash $manifest.version $manifest.url
            $manifest.autoupdate["url"] = "https://github.com/$owner/$name/archive/`$version.zip"
        } else {
            $manifest.url = "https://github.com/$owner/$name/archive/" + $info.default_branch + ".zip"
        }
    }

}

function calculate_hash($name, $url) {
    $confirm = Read-Host "Download $name to calculate hash ? (y/N)"
    if ($skip -or $confirm.ToLower() -eq 'y') {
        get_hash_for_app $null $null $null $url
    }
}

# GitHub names to SPDX identifiers
$licenses = @{ "Academic Free License v3.0" = "AFL-3.0";
               "Apache license 2.0" = "Apache-2.0";
               "Artistic license 2.0" = "Artistic-2.0";
               "Boost Software License 1.0" = "BSL-1.0";
               "BSD 2-clause `"Simplified`" license" = "BSD-2-Clause";
               "BSD 3-clause `"New`" or `"Revised`" license" = "BSD-3-Clause";
               "BSD 3-clause Clear license" = "BSD-3-Clause-Clear";
               "Creative Commons Zero v1.0 Universal" = "CC0-1.0";
               "Creative Commons Attribution 4.0" = "CC-BY-4.0";
               "Creative Commons Attribution Share Alike 4.0" = "CC-BY-SA-4.0";
               "Do What The F*ck You Want To Public License" = "WTFPL";
               "Educational Community License v2.0" = "ECL-2.0";
               "Eclipse Public License 1.0" = "EPL-1.0";
               "European Union Public License 1.1" = "EUPL-1.1";
               "GNU Affero General Public License v3.0" = "AGPL-3.0-only";
               "GNU General Public License v2.0" = "GPL-2.0-only";
               "GNU General Public License v3.0" = "GPL-3.0-only";
               "GNU Lesser General Public License v2.1" = "LGPL-2.1-only";
               "GNU Lesser General Public License v3.0" = "LGPL-3.0-only";
               "ISC" = "ISC";
               "LaTeX Project Public License v1.3c" = "LPPL-1.3c";
               "Microsoft Public License" = "MS-PL";
               "MIT" = "MIT";
               "Mozilla Public License 2.0" = "MPL-2.0";
               "Open Software License 3.0" = "OSL-3.0";
               "PostgreSQL License" = "PostgreSQL";
               "SIL Open Font License 1.1" = "OFL-1.1";
               "University of Illinois/NCSA Open Source License" = "NCSA";
               "The Unlicense" = "Unlicense";
               "zLib License" = "Zlib" }

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
