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
. "$PSScriptRoot\..\lib\system.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\uninstall.ps1" # 'uninstall_app'
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

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


# Run uninstallation for each app if necessary, continuing if there's
# a problem deleting a directory (which is quite likely)
function UninstallApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$global,
        [Parameter(Mandatory = $true)]
        [bool]$purge
    )

    $allDone = $true

    foreach ($app in installed_apps $global) {
        try {
            $succ = uninstall_app -app $app -global $global -purge $purge
            $errMsg = "Failed to uninstall $app."
        } catch {
            $succ = $false
            $errMsg = "Failed to uninstall $app : $($_.Exception.Message)."
        }

        if (-not $succ) {
            $allDone = $false
            error $errMsg
        }
    }

    if (-not $allDone) {
        abort 'Not all apps were uninstalled. Please try again or restart.'
    }
}

function RemoveDirs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$global,
        [Parameter(Mandatory = $true)]
        [bool]$purge
    )

    $dirs = @()

    # Remove the shortcut directory
    $dirs += (shortcut_folder $global)

    # Remove the scoop root directory
    $scoopDir = basedir $global
    $persistDir = "$scoopDir\persist"

    $dirs += (Get-ChildItem $scoopDir -Exclude @('persist', 'apps', 'shims') | Select-Object -ExpandProperty FullName)

    # Remove the persist directory if purge is specified or if it's empty
    $rmPersist = $purge -or
                ((Get-ChildItem -Path $persistDir -Force -ErrorAction SilentlyContinue).Count -eq 0)

    # Ensure shims dir and apps dir are removed last
    if ($rmPersist) {
        $dirs += @($persistDir, "$scoopDir\shims", "$scoopDir\apps", $scoopDir)
    } else {
        $dirs += @("$scoopDir\shims", "$scoopDir\apps")
    }

    foreach ($dir in $dirs) {
        try {
            if (($null -ne $dir) -and (Test-Path -Path $dir)) {
                Write-Host "Removing $(friendly_path $dir)..."

                Remove-Item -Path "$dir" -Recurse -Force -ErrorAction Stop
            }
        } catch {
            abort "Couldn't remove $(friendly_path $dir): $($_.Exception.Message)"
        }
    }
}

function RemoveEnvVars {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$global
    )

    # Remove environment variable "$scoopPathEnvVar"
    if (get_config USE_ISOLATED_PATH) {
        Remove-Path -Path ('%' + $scoopPathEnvVar + '%') -Global:$global -PassThru:$false
    }
}

function Invoke-SelfUninstall{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$global,
        [Parameter(Mandatory = $true)]
        [bool]$purge
    )

    UninstallApps -global $global -purge $purge
    RemoveDirs    -global $global -purge $purge
    RemoveEnvVars -global $global
}

if($global) {
    Invoke-SelfUninstall -global $true -purge $purge
}

Invoke-SelfUninstall -global $false -purge $purge

success 'Scoop has been uninstalled.'
