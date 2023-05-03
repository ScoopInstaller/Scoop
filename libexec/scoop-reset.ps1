# Usage: scoop reset <app>
# Summary: Reset an app to resolve conflicts
# Help: Used to resolve conflicts in favor of a particular app. For example,
# if you've installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
#
# You can use '*' in place of <app> or `-a`/`--all` switch to reset all apps.

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\shortcuts.ps1"

$opt, $apps, $err = getopt $args 'a' 'all'
if($err) { "scoop reset: $err"; exit 1 }
$all = $opt.a -or $opt.all

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

    #region Workaround for #2952
    if (test_running_process $app $global) {
        continue
    }
    #endregion Workaround for #2952

    $install = install_info $app $version $global
    $architecture = $install.architecture

    $dir = link_current $dir
    create_shims $manifest $dir $global $architecture
    create_startmenu_shortcuts $manifest $dir $global $architecture
    env_add_path $manifest $dir $global $architecture
    env_set $manifest $dir $global $architecture
    # unlink all potential old link before re-persisting
    unlink_persist_data $manifest $original_dir
    persist_data $manifest $original_dir $persist_dir
    persist_permission $manifest $global
}

exit 0
