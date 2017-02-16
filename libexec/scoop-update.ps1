# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   --global, -g       Update a globally installed app
#   --force, -f        Force update even when there isn't a newer version
#   --no-cache, -k     Don't use the download cache
#   --independent, -i  Don't install dependencies automatically
#   --quiet, -q        Hide extraneous messages
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

$opt, $apps, $err = getopt $args 'gfkqi' 'global','force', 'no-cache', 'quiet', 'independent'
if($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$use_cache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent

function update_scoop() {
    # check for git
    $git = try { gcm git -ea stop } catch { $null }
    if(!$git) { abort "Scoop uses Git to update itself. Run 'scoop install git' and try again." }

    "Updating Scoop..."
    $currentdir = fullpath $(versiondir 'scoop' 'current')
    if(!(test-path "$currentdir\.git")) {
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

        $newdir = fullpath $(versiondir 'scoop' 'new')

        # get git scoop
        git_clone -q $repo --branch $branch --single-branch "`"$newdir`""

        # check if scoop was successful downloaded
        if(!(test-path "$newdir")) {
            abort 'Scoop update failed.'
        }

        # replace non-git scoop with the git version
        rm -r -force $currentdir -ea stop
        mv $newdir $currentdir
    }
    else {
        pushd $currentdir
        git_pull -q
        $res = $lastexitcode
        if($res -ne 0) {
            abort 'Update failed.'
        }
        popd
    }

    ensure_scoop_in_path
    shim "$currentdir\bin\scoop.ps1" $false

    @(buckets) | % {
        "Updating '$_' bucket..."
        pushd (bucketdir $_)
        git_pull -q
        popd
    }
    success 'Scoop was updated successfully!'
}

function update($app, $global, $quiet = $false, $independent, $suggested) {
    $old_version = current_version $app $global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global
    $check_hash = $true

    # re-use architecture, bucket and url from first install
    $architecture = $install.architecture
    $bucket = $install.bucket
    $url = $install.url

    if(!$independent) {
        # check dependencies
        $deps = @(deps $app $architecture) | ? { !(installed $_) }
        $deps | % { install_app $_ $architecture $global $suggested }
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
            "Run 'scoop update' to check for new versions."
        }
        return
    }
    if(!$version) { abort "No manifest available for '$app'." } # installed from a custom bucket/no longer supported

    $manifest = manifest $app $bucket $url

    "Updating '$app' ($old_version -> $version)"

    $dir = versiondir $app $old_version $global

    "Uninstalling '$app' ($old_version)"
    run_uninstaller $old_manifest $architecture $dir
    rm_shims $old_manifest $global $architecture
    env_rm_path $old_manifest $dir $global
    env_rm $old_manifest $global
    # note: keep the old dir in case it contains user files

    "Installing '$app' ($version)"
    $dir = ensure (versiondir $app $version $global)

    # save info for uninstall
    save_installed_manifest $app $bucket $dir $url
    save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

    if($manifest.suggest) {
        $suggested[$app] = $manifest.suggest
    }

    $fname = dl_urls $app $version $manifest $architecture $dir $use_cache $check_hash
    unpack_inno $fname $manifest $dir
    pre_install $manifest $architecture
    run_installer $fname $manifest $architecture $dir $global
    ensure_install_dir_not_in_path $dir
    $dir = link_current $dir
    create_shims $manifest $dir $global $architecture
    env_add_path $manifest $dir $global
    env_set $manifest $dir $global
    post_install $manifest $architecture

    success "'$app' was updated from $old_version to $version."

    show_notes $manifest
}

function ensure_all_installed($apps, $global) {
    $app = $apps | ? { !(installed $_ $global) } | select -first 1 # just get the first one that's not installed
    if($app) {
        if(installed $app (!$global)) {
            function wh($g) { if($g) { "globally" } else { "for your account" } }
            write-host "'$app' isn't installed $(wh $global), but it is installed $(wh (!$global))." -f darkred
            "Try updating $(if($global) { 'without' } else { 'with' }) the --global (or -g) flag instead."
            exit 1
        } else {
            abort "'$app' isn't installed."
        }
    }
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
    return ,@($apps |% { ,@($_, $global) })
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

    if($apps -eq '*') {
        $apps = applist (installed_apps $false) $false
        if($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        ensure_all_installed $apps $global
        $apps = applist $apps $global
    }

    $suggested = @{};

    # $apps is now a list of ($app, $global) tuples
    $apps | % { update @_ $quiet $independent $suggested }
}

exit 0
