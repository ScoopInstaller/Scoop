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
$app, $bucket, $null = app $app
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

# Show installed versions
if($status.installed) {
    Write-Output "Installed:"
    $versions = versions $app $global
    $versions | ForEach-Object {
        $dir = versiondir $app $_ $global
        if($global) { $dir += " *global*" }
        Write-Output "  $dir"
    }
    Write-Output "Binaries:"
    $binaries = arch_specific 'bin' $manifest $install.architecture
    Write-Output "  $binaries"
} else {
    Write-Output "Installed: No"
}

# Manifest file
Write-Output "Manifest:`n  $manifest_file"

# Show notes
$dir = versiondir 'current' $global
$original_dir = versiondir $app $manifest.version $global
$persist_dir = persistdir $app $global
show_notes $manifest $dir $original_dir $persist_dir

exit 0
