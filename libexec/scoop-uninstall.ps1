# Usage: scoop uninstall <app> [options]
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
#
# Options:
#   -g, --global   Uninstall a globally installed app
#   -p, --purge    Remove all persistent data

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest' 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\system.ps1"
. "$PSScriptRoot\..\lib\shim.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\download.ps1" # url_filename
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\psmodules.ps1"
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'

# options
$opt, $apps, $err = getopt $args 'gp' 'global', 'purge'

if ($err) {
    error "scoop uninstall: $err"
    exit 1
}

$global = $opt.g -or $opt.global
$purge = $opt.p -or $opt.purge

if (!$apps) {
    error '<app> missing'
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to uninstall global apps.'
    exit 1
}

if ($apps -eq 'scoop') {
    & "$PSScriptRoot\..\bin\uninstall.ps1" $global $purge
    exit
}

$install_status = Confirm-InstallationStatus $apps -Global:$global
$apps = $install_status.installed
$failed = @{}
$install_status.failed.Keys | Where-Object { $install_status.failed[$_] -eq 'not installed in the requested scope' } | ForEach-Object { $failed[$_] = $install_status.failed[$_] }

:app_loop foreach ($_ in $apps) {
    ($app, $global) = $_

    $version = Select-CurrentVersion -AppName $app -Global:$global
    $appDir = appdir $app $global
    $app_key = app_key $app $global
    if ($version) {
        $dir = versiondir $app $version $global
        $persist_dir = persistdir $app $global

        $manifest = installed_manifest $app $version $global
        $install = install_info $app $version $global
        $architecture = $install.architecture
        $bucket = $install.bucket

        # an incomplete install is recorded as failed, and is what this cleans up
        $earlier_failure = $failed[$app_key]
        try {
            uninstall_version $app $manifest $version $architecture $global $failed $dir 'uninstalling'
        } catch {
            $failed[$app_key] = $_.Exception.Message
            error $_.Exception.Message
        }
        if ($failed[$app_key] -ne $earlier_failure) { continue }
        unlink_app $app $manifest $dir $persist_dir $global $architecture

        try {
            Remove-Item $dir -Recurse -Force -ErrorAction Stop
        } catch {
            if (Test-Path $dir) {
                error "Couldn't remove '$(friendly_path $dir)'; it may be in use."
                $failed[$app_key] = 'could not remove the app directory'
                continue
            }
        }

        try {
            Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -Arch $architecture
        } catch {
            $failed[$app_key] = $_.Exception.Message
            error $_.Exception.Message
            continue
        }
    }
    # remove older versions
    $oldVersions = @(Get-ChildItem $appDir -Name -Exclude 'current')
    foreach ($version in $oldVersions) {
        Write-Host "Removing older version ($version)."
        $dir = versiondir $app $version $global
        try {
            # unlink all potential old link before doing recursive Remove-Item
            unlink_persist_data $manifest $dir
            Remove-Item $dir -Recurse -Force -ErrorAction Stop
        } catch {
            error "Couldn't remove '$(friendly_path $dir)'; it may be in use."
            $failed[$app_key] = 'could not remove an old version'
            continue app_loop
        }
    }
    if (Test-Path ($currentDir = Join-Path $appDir 'current')) {
        attrib $currentDir -R /L
        Remove-Item $currentDir -ErrorAction Stop -Force
    }
    if (!(Get-ChildItem $appDir)) {
        try {
            # if last install failed, the directory seems to be locked and this
            # will throw an error about the directory not existing
            Remove-Item $appdir -Recurse -Force -ErrorAction Stop
        } catch {
            if ((Test-Path $appdir)) { throw } # only throw if the dir still exists
        }
    }

    # purge persistent data
    if ($purge) {
        Write-Host 'Removing persisted data.'
        $persist_dir = persistdir $app $global

        if (Test-Path $persist_dir) {
            try {
                Remove-Item $persist_dir -Recurse -Force -ErrorAction Stop
            } catch {
                error "Couldn't remove '$(friendly_path $persist_dir)'; it may be in use."
                $failed[$app_key] = 'could not remove the persisted data'
                continue
            }
        }
    }

    success "'$app' was uninstalled."
}

$failed_count = show_failed_apps $failed 'uninstall'

exit [int]($failed_count -gt 0)
