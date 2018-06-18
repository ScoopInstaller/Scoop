# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   -f, --force               Force update even when there isn't a newer version
#   -g, --global              Update a globally installed app
#   -i, --independent         Don't install dependencies automatically
#   -k, --no-cache            Don't use the download cache
#   -s, --skip                Skip hash validation (use with caution!)
#   -q, --quiet               Hide extraneous messages

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\shortcuts.ps1"
. "$psscriptroot\..\lib\psmodules.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\git.ps1"
. "$psscriptroot\..\lib\install.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'gfiksq:' 'global', 'force', 'independent', 'no-cache', 'skip', 'quiet'
if($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$check_hash = !($opt.s -or $opt.skip)
$use_cache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent

# load config
$repo = $(scoop config SCOOP_REPO)
if(!$repo) {
    $repo = "https://github.com/lukesampson/scoop"
    scoop config SCOOP_REPO "$repo"
}

$branch = $(scoop config SCOOP_BRANCH)
if(!$branch) {
    $branch = "master"
    scoop config SCOOP_BRANCH "$branch"
}

function update_scoop() {
    # check for git
    $git = try { Get-Command git -ea stop } catch { $null }
    if(!$git) { abort "Scoop uses Git to update itself. Run 'scoop install git' and try again." }

    write-host "Updating Scoop..."
    $last_update = $(last_scoop_update).ToString('s')
    $show_update_log = get_config "show_update_log"
    if($null -eq $show_update_log) {
        $show_update_log = $true
    }
    $currentdir = fullpath $(versiondir 'scoop' 'current')
    if(!(test-path "$currentdir\.git")) {
        $newdir = fullpath $(versiondir 'scoop' 'new')

        # get git scoop
        git_clone -q $repo --branch $branch --single-branch "`"$newdir`""

        # check if scoop was successful downloaded
        if(!(test-path "$newdir")) {
            abort 'Scoop update failed.'
        }

        # replace non-git scoop with the git version
        Remove-Item -r -force $currentdir -ea stop
        Move-Item $newdir $currentdir
    }
    else {
        Push-Location $currentdir
        git_pull -q
        $res = $lastexitcode
        if($show_update_log) {
            git_log --no-decorate --date=local --since="`"$last_update`"" --format="`"tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset`"" HEAD
        }
        Pop-Location
        if($res -ne 0) {
            abort 'Update failed.'
        }
    }

    ensure_scoop_in_path
    shim "$currentdir\bin\scoop.ps1" $false

    @(buckets) | ForEach-Object {
        write-host "Updating '$_' bucket..."
        Push-Location (bucketdir $_)
        git_pull -q
        if($show_update_log) {
            git_log --no-decorate --date=local --since="`"$last_update`"" --format="`"tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset`"" HEAD
        }
        Pop-Location
    }

    scoop config lastupdate (get-date)
    success 'Scoop was updated successfully!'
}

function update($app, $global, $quiet = $false, $independent, $suggested, $use_cache = $true, $check_hash = $true) {
    $old_version = current_version $app $global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global

    # re-use architecture, bucket and url from first install
    $architecture = ensure_architecture $install.architecture
    $bucket = $install.bucket
    $url = $install.url

    if(!$independent) {
        # check dependencies
        $deps = @(deps $app $architecture) | Where-Object { !(installed $_) }
        $deps | ForEach-Object { install_app $_ $architecture $global $suggested $use_cache $check_hash }
    }

    $version = latest_version $app $bucket $url
    $is_nightly = $version -eq 'nightly'
    if($is_nightly) {
        $version = nightly_version $(get-date) $quiet
        $check_hash = $false
    }

    if(!$force -and ($old_version -eq $version)) {
        if (!$quiet) {
            warn "The latest version of '$app' ($version) is already installed."
        }
        return
    }
    if(!$version) {
        # installed from a custom bucket/no longer supported
        error "No manifest available for '$app'."
        return
    }

    $manifest = manifest $app $bucket $url

    write-host "Updating '$app' ($old_version -> $version)"

    $dir = versiondir $app $old_version $global

    write-host "Uninstalling '$app' ($old_version)"
    run_uninstaller $old_manifest $architecture $dir
    rm_shims $old_manifest $global $architecture
    env_rm_path $old_manifest $dir $global
    env_rm $old_manifest $global

    # If a junction was used during install, that will have been used
    # as the reference directory. Otherwise it will just be the version
    # directory.
    $refdir = unlink_current $dir

    if($bucket) {
        # add bucket name it was installed from
        $app = "$bucket/$app"
    }
    install_app $app $architecture $global $suggested $use_cache $check_hash
}

if(!$apps) {
    if($global) {
        "scoop update: --global is invalid when <app> is not specified."; exit 1
    }
    if (!$use_cache) {
        "scoop update: --no-cache is invalid when <app> is not specified."; exit 1
    }
    update_scoop
} else {
    if($global -and !(is_admin)) {
        'ERROR: You need admin rights to update global apps.'; exit 1
    }

    if(is_scoop_outdated) {
        update_scoop
    }
    $outdated = @()
    $apps_param = $apps

    if($apps_param -eq '*') {
        $apps = applist (installed_apps $false) $false
        if($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        $apps = ensure_all_installed $apps_param $global
    }
    if($apps) {
        $apps | ForEach-Object {
            ($app, $global) = $_
            $status = app_status $app $global
            if($force -or $status.outdated) {
                $outdated += applist $app $global
                write-host -f yellow ("$app`: $($status.version) -> $($status.latest_version){0}" -f ('',' (global)')[$global])
            } elseif($apps_param -ne '*') {
                write-host -f green "$app`: $($status.version) (latest version)"
            }
        }

        if($outdated.Length -gt 1) { write-host -f DarkCyan "Updating $($outdated.Length) outdated apps:" }
        elseif($outdated.Length -eq 0) { write-host -f Green "Latest versions for all apps are installed! For more information try 'scoop status'" }
        else { write-host -f DarkCyan "Updating one outdated app:" }
    }

    $suggested = @{};
    # # $outdated is a list of ($app, $global) tuples
    $outdated | ForEach-Object { update @_ $quiet $independent $suggested $use_cache $check_hash }
}

exit 0
