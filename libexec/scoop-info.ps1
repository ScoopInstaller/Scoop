# Usage: scoop info <app>
# Summary: Display information about an app
param($app)

. "$PSScriptRoot\..\lib\depends.ps1"
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
    $manifest, $bucket = find_manifest $app $bucket
}

if (!$manifest) {
    abort "Could not find manifest for '$(show_app $app $bucket)'."
}

$install = install_info $app $status.version $global
$status.installed = $install.bucket -eq $bucket
$version_output = $manifest.version
if (!$manifest_file) {
    $manifest_file = manifest_path $app $bucket
}

$dir = currentdir $app $global
$original_dir = versiondir $app $manifest.version $global
$persist_dir = persistdir $app $global

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
$item.Website = $manifest.homepage
# Show license
if ($manifest.license) {
    $license = $manifest.license
    if ($manifest.license.identifier -and $manifest.license.url) {
        $license = "$($manifest.license.identifier) ($($manifest.license.url))"
    } elseif ($manifest.license -match '^((ht)|f)tps?://') {
        $license = "$($manifest.license)"
    } elseif ($manifest.license -match '[|,]') {
        $licurl = $manifest.license.Split("|,") | ForEach-Object {"https://spdx.org/licenses/$_.html"}
        $license = "$($manifest.license) ($($licurl -join ', '))"
    } else {
        $license = "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)"
    }
    $item.License = $license
}

# Manifest file
$item.Manifest = $manifest_file

if ($status.installed) {
    # Show installed versions
    $installed_output = ""
    Get-InstalledVersion -AppName $app -Global:$global | ForEach-Object {
        $installed_output += "`n$(versiondir $app $_ $global)"
    }
    $item.Installed = $installed_output
}

$binaries = @(arch_specific 'bin' $manifest $install.architecture)
if ($binaries) {
    $binary_output = ""
    $binaries | ForEach-Object {
        if ($_ -is [System.Array]) {
            $binary_output += "`n$($_[1]).exe"
        } else {
            $binary_output += "`n$_"
        }
    }
    $item.Binaries = $binary_output
}
$env_set = (arch_specific 'env_set' $manifest $install.architecture)
$env_add_path = (arch_specific 'env_add_path' $manifest $install.architecture)
if ($env_set) {
    $env_vars = ""
    $env_set | Get-Member -member noteproperty | ForEach-Object {
        $value = env $_.name $global
        if (!$value) {
            $value = format $env_set.$($_.name) @{ "dir" = $dir }
        }
        $env_vars += "`n$($_.name) = $value"
    }
    $item.'Environment Variables' = $env_vars
}
if ($env_add_path) {
    $env_path = ""
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        if ($_ -eq '.') {
            $env_path += "`n$dir"
        } else {
            $env_path += "`n$dir\$_"
        }
    }
    $item.'Path Additions' = $env_path
}

if ($manifest.notes) {
    # Show notes
    $item.Notes = "`n" + ((substitute $manifest.notes @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir}) -join "`n")
}

[PSCustomObject]$item

exit 0
