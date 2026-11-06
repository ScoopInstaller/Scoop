# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   -f, --force            Force update even when there isn't a newer version
#   -g, --global           Update a globally installed app
#   -i, --independent      Don't install dependencies automatically
#   -k, --no-cache         Don't use the download cache
#   -s, --skip-hash-check  Skip hash validation (use with caution!)
#   -q, --quiet            Hide extraneous messages
#   -a, --all              Update all apps (alternative to '*')

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'save_install_info' in 'manifest.ps1' (indirectly)
. "$PSScriptRoot\..\lib\system.ps1"
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\psmodules.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\depends.ps1"
. "$PSScriptRoot\..\lib\shim.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\download.ps1"
. "$PSScriptRoot\..\lib\update.ps1"
if (get_config USE_SQLITE_CACHE) {
    . "$PSScriptRoot\..\lib\database.ps1"
}

$opt, $apps, $err = getopt $args 'gfiksqa' 'global', 'force', 'independent', 'no-cache', 'skip-hash-check', 'quiet', 'all'
if ($err) { error "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$check_hash = !($opt.s -or $opt.'skip-hash-check')
$use_cache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent
$all = $opt.a -or $opt.all

if (($PSVersionTable.PSVersion.Major) -lt 5) {
    # check powershell version
    Write-Output 'PowerShell 5 or later is required to run Scoop.'
    Write-Output 'Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows'
    break
}
$show_update_log = get_config SHOW_UPDATE_LOG $true
$failed = @{}

if (-not ($apps -or $all)) {
    if ($global) {
        error 'scoop update: --global is invalid when <app> is not specified.'
        exit 1
    }
    if (!$use_cache) {
        error 'scoop update: --no-cache is invalid when <app> is not specified.'
        exit 1
    }
    Sync-Scoop -Log:$show_update_log
    Sync-Bucket -Log:$show_update_log
    set_config LAST_UPDATE ([System.DateTime]::Now.ToString('o')) | Out-Null
    success 'Scoop was updated successfully!'
} else {
    if ($global -and !(is_admin)) {
        error 'You need admin rights to update global apps.'; exit 1
    }

    $outdated = @()
    $updateScoop = $null -ne ($apps | Where-Object { $_ -eq 'scoop' }) -or (is_scoop_outdated)
    $apps = $apps | Where-Object { $_ -ne 'scoop' }
    $apps_param = $apps

    if ($updateScoop) {
        Sync-Scoop -Log:$show_update_log
        Sync-Bucket -Log:$show_update_log
        set_config LAST_UPDATE ([System.DateTime]::Now.ToString('o')) | Out-Null
        success 'Scoop was updated successfully!'
    }

    if ($apps_param -eq '*' -or $all) {
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        if ($apps_param) {
            $install_status = Confirm-InstallationStatus $apps_param -Global:$global
            $apps = $install_status.installed
            $install_status.failed.Keys | ForEach-Object { $failed[$_] = $install_status.failed[$_] }
        }
    }
    if ($apps) {
        $apps | ForEach-Object {
            ($app, $global) = $_
            $status = app_status $app $global
            $is_pin = $status.pinned
            if ($status.installed -and ($force -or $status.outdated)) {
                if (!$status.hold) {
                    if ($is_pin -and !$force) {
                        $app_key = if ($global) { "$app (global)" } else { $app }
                        $failed[$app_key] = "skipped: pinned to version $($status.version)"
                        warn "'$app' is pinned to version $($status.version), $($status.latest_version) is available.`nUse 'scoop update -f $app$(if ($global) { ' --global' })' to install the new version."
                        return
                    }
                    $outdated += applist $app $global
                    $latest = if ($force -and $is_pin) { 'HEAD (forced)' } else { $status.latest_version }
                    Write-Host -f yellow ("$app`: $($status.version) -> $latest{0}" -f ('', ' (global)')[$global])
                } else {
                    $app_key = if ($global) { "$app (global)" } else { $app }
                    $failed[$app_key] = "skipped: held to version $($status.version)"
                    warn "'$app' is held to version $($status.version)`nUse 'scoop unhold $app$(if ($global) { ' --global' })' to enable updates."
                }
            } elseif ($apps_param -ne '*' -and !$all) {
                if ($status.installed) {
                    ensure_none_failed $app
                    Write-Host "$app`: $($status.version) (latest version)" -ForegroundColor Green
                } else {
                    info 'Please reinstall it or fix the manifest.'
                }
            }
        }

        if ($outdated -and ((Test-Aria2Enabled) -and (get_config 'aria2-warning-enabled' $true))) {
            warn "Scoop uses 'aria2c' for multi-connection downloads."
            warn "Should it cause issues, run 'scoop config aria2-enabled false' to disable it."
            warn "To disable this warning, run 'scoop config aria2-warning-enabled false'."
        }
        if ($outdated.Length -gt 1) {
            Write-Host -f DarkCyan "Updating $($outdated.Length) outdated apps:"
        } elseif ($outdated.Length -eq 0) {
            $skipped = @($failed.Keys | Where-Object { $failed[$_] -like 'skipped:*' })
            if (!$skipped.Count) {
                Write-Host -f Green "Latest versions for all apps are installed! For more information try 'scoop status'"
            }
        } else {
            Write-Host -f DarkCyan 'Updating one outdated app:'
        }
    }

    $suggested = @{}
    # $outdated is a list of ($app, $global) tuples
    $outdated | ForEach-Object {
    $current = $_
    try {
        update_app @current $force $quiet $independent $suggested $failed $use_cache $check_hash
    } catch {
        $key = if ($current[1]) { "$($current[0]) (global)" } else { $current[0] }
        $failed[$key] = $_.Exception.Message
        error $_.Exception.Message
    }
}

    show_suggestions $suggested
    $failed_count = show_failed_apps $failed 'update'
}

exit [int]($failed_count -gt 0)
