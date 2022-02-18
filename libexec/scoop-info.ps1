# Usage: scoop info <app>
# Summary: Display information about an app
param([string]$app, [switch]$verbose)

. "$PSScriptRoot\..\lib\help.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"

reset_aliases

if (!$app) { my_usage; exit 1 }

if ($app -match '^(ht|f)tps?://|\\\\') {
    # check if $app is a URL or UNC path
    $url = $app
    $app = appname_from_url $url
    $global = installed $app $true
    $status = app_status $app $global
    $manifest = url_manifest $url
    $manifest_file = $url
} else {
    # else $app is a normal app name
    $global = installed $app $true
    $app, $bucket, $null = parse_app $app
    $status = app_status $app $global
    $app, $manifest, $bucket, $url = Find-Manifest $app $bucket
}

if (!$manifest) {
    abort "Could not find manifest for '$(show_app $app $bucket)'."
}

$install = install_info $app $status.version $global
$status.installed = $bucket -and $install.bucket -eq $bucket
$version_output = $manifest.version
if (!$manifest_file) {
    $manifest_file = if ($bucket) { manifest_path $app $bucket } else { $url }
}

if ($verbose) {
    $dir = currentdir $app $global
    $original_dir = versiondir $app $manifest.version $global
    $persist_dir = persistdir $app $global
} else {
    $dir, $original_dir, $persist_dir = "<root>", "<root>", "<root>"
}

if ($status.installed) {
    $manifest_file = manifest_path $app $install.bucket
    if ($install.url) {
        $manifest_file = $install.url
    }
    if ($status.version -eq $manifest.version) {
        $version_output = $status.version
    } else {
        $version_output = "$($status.version) (Update to $($manifest.version) available)"
    }
}

$item = [ordered]@{ Name = $app }
if ($manifest.description) {
    $item.Description = $manifest.description
}
$item.Version = $version_output
if ($manifest.homepage) {
    $item.Website = $manifest.homepage.TrimEnd('/') -replace "^https?:\/\/", ""
}
# Show license
if ($manifest.license) {
    $item.License = if ($manifest.license.identifier -and $manifest.license.url) {
        if ($verbose) { "$($manifest.license.identifier) ($($manifest.license.url))" } else { $manifest.license.identifier }
    } elseif ($manifest.license -match '^((ht)|f)tps?://') {
        $manifest.license
    } elseif ($manifest.license -match '[|,]') {
        if ($verbose) {
            "$($manifest.license) ($(($manifest.license -Split "\||," | ForEach-Object { "https://spdx.org/licenses/$_.html" }) -join ', '))"
        } else {
            $manifest.license
        }
    } else {
        if ($verbose) { "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)" } else { $manifest.license }
    }
}

# Manifest file
if ($verbose) { $item.Manifest = $manifest_file }

if ($status.installed) {
    # Show installed versions
    $installed_output = @()
    Get-InstalledVersion -AppName $app -Global:$global | ForEach-Object {
        $installed_output += if ($verbose) { versiondir $app $_ $global } else { "$_$(if ($global) { " *global*" })" }
    }
    $item.Installed = $installed_output -join "`n"
}

$binaries = @(arch_specific 'bin' $manifest $install.architecture)
if ($binaries) {
    $binary_output = @()
    $binaries | ForEach-Object {
        if ($_ -is [System.Array]) {
            $binary_output += "$($_[1]).exe"
        } else {
            $binary_output += $_
        }
    }
    $item.Binaries = $binary_output -join " | "
}
$env_set = (arch_specific 'env_set' $manifest $install.architecture)
$env_add_path = (arch_specific 'env_add_path' $manifest $install.architecture)
if ($env_set) {
    $env_vars = @()
    $env_set | Get-Member -member noteproperty | ForEach-Object {
        $env_vars += "$($_.name) = $(format $env_set.$($_.name) @{ "dir" = $dir })"
    }
    $item.Environment = $env_vars -join "`n"
}
if ($env_add_path) {
    $env_path = @()
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        if ($_ -eq '.') {
            $env_path += $dir
        } else {
            $env_path += "$dir\$_"
        }
    }
    $item.'Path Added' = $env_path -join "`n"
}

if ($manifest.notes) {
    # Show notes
    $item.Notes = (substitute $manifest.notes @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir }) -join "`n"
}

[PSCustomObject]$item

exit 0
