# Usage: scoop info <app>
# Summary: Display information about an app
param($app)

. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"

reset_aliases

if(!$app) { my_usage; exit 1 }

$global = installed $app $true
$app, $bucket, $null = parse_app $app
$status = app_status $app $global
$manifest, $bucket = find_manifest $app $bucket

if (!$manifest) {
    if ($bucket) {
        abort "Could not find manifest for '$bucket/$app'."
    } else {
        abort "Could not find manifest for '$app'."
    }
}

$install = install_info $app $status.version $global
$manifest_file = manifest_path $app $bucket
$version_output = $manifest.version

$dir = versiondir $app 'current' $global
$original_dir = versiondir $app $manifest.version $global
$persist_dir = persistdir $app $global

if($status.installed) {
    $bucket = $install.bucket
    $manifest_file = manifest_path $app $bucket
    if($install.url) { $manifest_file = $install.url }
    if($status.version -eq $manifest.version) {
        $version_output = $status.version
    } else {
        $version_output = "$($status.version) (Update to $($manifest.version) available)"
    }
}

Write-Output "Name:      $app"
if ($manifest.description) {
    Write-Output "  $($manifest.description)"
}
Write-Output "Version:   $version_output"
Write-Output "Website:   $($manifest.homepage)"
# Show license
if ($manifest.license) {
    $license = $manifest.license
    if($manifest.license -notmatch '^((ht)|f)tps?://') {
        $license = "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)"
    }
    Write-Output "License:   $license"
}

# Manifest file
Write-Output "Manifest:`n  $manifest_file"

if($status.installed) {
    # Show installed versions
    Write-Output "Installed:"
    $versions = versions $app $global
    $versions | ForEach-Object {
        $dir = versiondir $app $_ $global
        if($global) { $dir += " *global*" }
        Write-Output "  $dir"
    }
} else {
    Write-Output "Installed: No"
}

$binaries = arch_specific 'bin' $manifest $install.architecture
if($binaries) {
    Write-Output "Binaries:`n  $binaries"
}

if($manifest.env_set -or $manifest.env_add_path) {
    if($status.installed) {
        Write-Output "Environment:"
    } else {
        Write-Output "Environment: (simulated)"
    }
}
if($manifest.env_set) {
    $manifest.env_set | Get-Member -member noteproperty | ForEach-Object {
        $value = env $_.name $global
        if(!$value) {
            $value = format $manifest.env_set.$($_.name) @{ "dir" = $dir }
        }
        Write-Output "  $($_.name)=$value"
    }
}
if($manifest.env_add_path) {
    $manifest.env_add_path | Where-Object { $_ } | ForEach-Object {
        if($_ -eq '.') {
            Write-Output "  PATH=%PATH%;$dir"
        } else {
            Write-Output "  PATH=%PATH%;$dir\$_"
        }
    }
}

# Show notes
show_notes $manifest $dir $original_dir $persist_dir

exit 0
