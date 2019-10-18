<#
.SYNOPSIS
    Uninstall ALL scoop applications and scoop itself.
.PARAMETER global
    Global applications will be uninstalled.
.PARAMETER purge
    Persisted data will be deleted.
#>
param(
    [bool] $global,
    [bool] $purge
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Join-Path $PSScriptRoot '..\lib\Uninstall.psm1'

if ($global -and !(is_admin)) {
    error 'You need admin rights to uninstall globally.'
    exit 1
}

if ($purge) {
    warn 'This will uninstall Scoop, all the programs that have been installed with Scoop and all persisted data!'
} else {
    warn 'This will uninstall Scoop and all the programs that have been installed with Scoop!'
}
$yn = Read-Host 'Are you sure? (yN)'
if ($yn -notlike 'y*') { exit }

$errors = $false

function rm_dir($dir) {
    try {
        Remove-Item $dir -Recurse -Force -ErrorAction Stop
    } catch {
        abort "Couldn't remove $(friendly_path $dir): $_"
    }
}

# Remove all folders (except persist) inside given scoop directory.
function keep_onlypersist($directory) {
    Get-ChildItem $directory -Exclude 'persist' | ForEach-Object { rm_dir $_ }
}

# Run uninstallation for each app if necessary, continuing if there's
# a problem deleting a directory (which is quite likely)
if ($global) {
    installed_apps $true | ForEach-Object { # global apps
        $errors = Uninstall-ScoopApplication -App $_ -Global:$true
    }
}

installed_apps $false | ForEach-Object { # local apps
    $errors = Uninstall-ScoopApplication -App $_ -Global:$false
}

if ($errors) { abort 'Not all apps could be deleted. Try again or restart.' }

if ($purge) {
    rm_dir $scoopdir
    if ($global) { rm_dir $globaldir }
} else {
    keep_onlypersist $scoopdir
    if ($global) { keep_onlypersist $globaldir }
}

remove_from_path (shimdir $false)
if ($global) { remove_from_path (shimdir $true) }

success 'Scoop has been uninstalled.'
