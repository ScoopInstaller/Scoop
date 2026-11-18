# Usage: scoop reset <app>
# Summary: Reset an app to resolve conflicts
# Help: Used to resolve conflicts in favor of a particular app. For example,
# if you've installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
#
# You can use '*' in place of <app> or `-a`/`--all` switch to reset all apps.

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'install_app' (indirectly)
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\system.ps1" # 'env_add_path' (indirectly)
. "$PSScriptRoot\..\lib\shim.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\download.ps1" # 'install_app' (indirectly)
. "$PSScriptRoot\..\lib\decompress.ps1" # 'install_app' (indirectly)
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\depends.ps1" # 'Test-7zipRequirement' in 'decompress.ps1' (indirectly)
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\psmodules.ps1"

$opt, $apps, $err = getopt $args 'a' 'all'
if($err) { error "scoop reset: $err"; exit 1 }
$all = $opt.a -or $opt.all
$failed = @{}

if(!$apps -and !$all) { error '<app> missing'; my_usage; exit 1 }

if($apps -eq '*' -or $all) {
    $local = installed_apps $false | ForEach-Object { ,@($_, $false) }
    $global = installed_apps $true | ForEach-Object { ,@($_, $true) }
    $apps = @($local) + @($global)
}

$apps | ForEach-Object {
    ($app, $global) = $_

    $app, $bucket, $version = parse_app $app

    if(($global -eq $null) -and (installed $app $true)) {
        # set global flag when running reset command on specific app
        $global = $true
    }

    if($app -eq 'scoop') {
        # skip scoop
        return
    }

    if(!(installed $app)) {
        error "'$app' isn't installed"
        return
    }

    if ($null -eq $version) {
        $version = Select-CurrentVersion -AppName $app -Global:$global
    }

    $manifest = installed_manifest $app $version $global
    # if this is null we know the version they're resetting to
    # is not installed
    if ($manifest -eq $null) {
        error "'$app ($version)' isn't installed"
        return
    }

    if($global -and !(is_admin)) {
        warn "'$app' ($version) is a global app. You need admin rights to reset it. Skipping."
        return
    }

    write-host "Resetting $app ($version)."

    $dir = Convert-Path (versiondir $app $version $global)
    $original_dir = $dir
    $persist_dir = persistdir $app $global

    if (test_running_process $app $global) {
        Write-Host 'Running process detected, skip resetting.'
        $failed[$app] = 'blocked: running process'
        return
    }

    $install = install_info $app $version $global
    $architecture = $install.architecture
    # the dependencies of the installed version, not the ones the manifest has now
    try {
        $deps = @($manifest.depends | Where-Object { $_ -and !(installed $_) } | ForEach-Object { Get-Dependency $_ $architecture } | Select-Object -Unique)
    } catch {
        $failed[$app] = $_.Exception.Message
        error $_.Exception.Message
        return
    }
    $suggested = @{}
    $deps.Where({ !(installed $_) }) | ForEach-Object { install_app $_ $architecture $global $suggested $failed }
    $failed_deps = failed_deps $manifest $failed
    if ($failed_deps.Count -gt 0) {
        error "'$app' depends on $($failed_deps -join ', '), which failed."
        $failed[$app] = "dependency failed: $($failed_deps -join ', ')"
        return
    }

    $dir = link_current $dir
    # unset all potential old env before re-adding
    env_rm_path $manifest $dir $persist_dir $global $architecture
    env_rm $manifest $global $architecture
    link_app $manifest $dir $original_dir $persist_dir $global $architecture
}

$failed_count = show_failed_apps $failed 'reset'

exit [int]($failed_count -gt 0)
