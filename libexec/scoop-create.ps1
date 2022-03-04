# Usage: scoop create <url>
# Summary: Create a custom app manifest
# Help: Create your own custom app manifest
param($url)

function create_manifest($url) {
    $manifest = new_manifest

    $manifest.url = $url

    $url_parts = $null
    try {
        $url_parts = parse_url $url
    } catch {
        abort "Error: $url is not a valid URL"
    }

    $name = choose_item $url_parts 'App name'
    $name = if ($name.Length -gt 0) {
        $name
    } else {
        file_name ($url_parts | Select-Object -Last 1)
    }

    $manifest.version = choose_item $url_parts 'Version'

    $manifest | ConvertTo-Json | Out-File -FilePath "$name.json" -Encoding ascii
    $manifest_path = Join-Path $pwd "$name.json"
    Write-Host "Created '$manifest_path'."
}

function new_manifest() {
    @{ 'homepage' = ''; 'license' = ''; 'version' = ''; 'url' = '';
        'hash' = ''; 'extract_dir' = ''; 'bin' = ''; 'depends' = ''
    }
}

function file_name($segment) {
    $segment.Substring(0, $segment.lastindexof('.'))
}

function parse_url($url) {
    $uri = New-Object System.Uri $url
    $uri.pathandquery.Substring(1).Split('/')
}

function choose_item($list, $query) {
    for ($i = 0; $i -lt $list.Count; $i++) {
        $item = $list[$i]
        Write-Host "$($i + 1)) $item"
    }
    $sel = Read-Host $query

    if ($sel.Trim() -match '^[0-9+]$') {
        return $list[$sel - 1]
    }

    $sel
}

if (!$url) {
    scoop help create
} else {
    create_manifest $url
}

exit 0
