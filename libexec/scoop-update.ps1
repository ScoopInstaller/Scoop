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
#   -a, --all                 Update all apps (alternative to '*')

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'save_install_info' in 'manifest.ps1' (indirectly)
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\psmodules.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\depends.ps1"
. "$PSScriptRoot\..\lib\install.ps1"

$opt, $apps, $err = getopt $args 'gfiksqa' 'global', 'force', 'independent', 'no-cache', 'skip', 'quiet', 'all'
if ($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force
$check_hash = !($opt.s -or $opt.skip)
$use_cache = !($opt.k -or $opt.'no-cache')
$quiet = $opt.q -or $opt.quiet
$independent = $opt.i -or $opt.independent
$all = $opt.a -or $opt.all

# load config
$configRepo = get_config SCOOP_REPO
if (!$configRepo) {
    $configRepo = "https://github.com/ScoopInstaller/Scoop"
    set_config SCOOP_REPO $configRepo | Out-Null
}

# Find current update channel from config
$configBranch = get_config SCOOP_BRANCH
if (!$configBranch) {
    $configBranch = "master"
    set_config SCOOP_BRANCH $configBranch | Out-Null
}

if(($PSVersionTable.PSVersion.Major) -lt 5) {
    # check powershell version
    Write-Output "PowerShell 5 or later is required to run Scoop."
    Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows"
    break
}

function update_scoop() {
    # check for git
    if(!(Test-CommandAvailable git)) { abort "Scoop uses Git to update itself. Run 'scoop install git' and try again." }

    Write-Host "Updating Scoop..."
    $last_update = $(last_scoop_update)
    if ($null -eq $last_update) {$last_update = [System.DateTime]::Now}
    $last_update = $last_update.ToString('s')
    $show_update_log = get_config 'show_update_log' $true
    $currentdir = fullpath $(versiondir 'scoop' 'current')
    if (!(Test-Path "$currentdir\.git")) {
        $newdir = fullpath $(versiondir 'scoop' 'new')

        # get git scoop
        git_cmd clone -q $configRepo --branch $configBranch --single-branch "`"$newdir`""

        # check if scoop was successful downloaded
        if (!(Test-Path "$newdir")) {
            abort 'Scoop update failed.'
        }

        # replace non-git scoop with the git version
        Remove-Item -r -force $currentdir -ea stop
        Move-Item $newdir $currentdir
    } else {
        $previousCommit = Invoke-Expression "git -C '$currentdir' rev-parse HEAD"
        $currentRepo = Invoke-Expression "git -C '$currentdir' config remote.origin.url"
        $currentBranch = Invoke-Expression "git -C '$currentdir' branch"

        $isRepoChanged = !($currentRepo -match $configRepo)
        $isBranchChanged = !($currentBranch -match "\*\s+$configBranch")

        # Change remote url if the repo is changed
        if ($isRepoChanged) {
            Invoke-Expression "git -C '$currentdir' config remote.origin.url '$configRepo'"
        }

        # Fetch and reset local repo if the repo or the branch is changed
        if ($isRepoChanged -or $isBranchChanged) {
            # Reset git fetch refs, so that it can fetch all branches (GH-3368)
            Invoke-Expression "git -C '$currentdir' config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'"
            # fetch remote branch
            git_cmd -C "`"$currentdir`"" fetch --force origin "refs/heads/`"$configBranch`":refs/remotes/origin/$configBranch" -q
            # checkout and track the branch
            git_cmd -C "`"$currentdir`"" checkout -B $configBranch -t origin/$configBranch -q
            # reset branch HEAD
            Invoke-Expression "git -C '$currentdir' reset --hard origin/$configBranch -q"
        } else {
            git_cmd -C "`"$currentdir`"" pull -q
        }

        $res = $lastexitcode
        if ($show_update_log) {
            Invoke-Expression "git -C '$currentdir' --no-pager log --no-decorate --grep='^(chore)' --invert-grep --format='tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset' '$previousCommit..HEAD'"
        }

        if ($res -ne 0) {
            abort 'Update failed.'
        }
    }

    # This should have been deprecated after 2019-05-12
    # if ((Get-LocalBucket) -notcontains 'main') {
    #     info "The main bucket of Scoop has been separated to 'https://github.com/ScoopInstaller/Main'"
    #     info "Adding main bucket..."
    #     add_bucket 'main'
    # }

    shim "$currentdir\bin\scoop.ps1" $false

    foreach ($bucket in Get-LocalBucket) {
        Write-Host "Updating '$bucket' bucket..."

        $bucketLoc = Find-BucketDirectory $bucket -Root

        if (!(Test-Path (Join-Path $bucketLoc '.git'))) {
            if ($bucket -eq 'main') {
                # Make sure main bucket, which was downloaded as zip, will be properly "converted" into git
                Write-Host " Converting 'main' bucket to git..."
                rm_bucket 'main'
                add_bucket 'main'
            } else {
                Write-Host "'$bucket' is not a git repository. Skipped."
            }
            continue
        }

        $previousCommit = (Invoke-Expression "git -C '$bucketLoc' rev-parse HEAD")
        git_cmd -C "`"$bucketLoc`"" pull -q
        if ($show_update_log) {
            Invoke-Expression "git -C '$bucketLoc' --no-pager log --no-decorate --grep='^(chore)' --invert-grep --format='tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset' '$previousCommit..HEAD'"
        }
    }

    set_config lastupdate ([System.DateTime]::Now.ToString('o')) | Out-Null
    success 'Scoop was updated successfully!'
}

function update($app, $global, $quiet = $false, $independent, $suggested, $use_cache = $true, $check_hash = $true) {
    $old_version = Select-CurrentVersion -AppName $app -Global:$global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global

    # re-use architecture, bucket and url from first install
    $architecture = ensure_architecture $install.architecture
    $bucket = $install.bucket
    if ($null -eq $bucket) {
        $bucket = 'main'
    }
    $url = $install.url

    $manifest = manifest $app $bucket $url
    $version = $manifest.version
    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $(get-date) $quiet
        $check_hash = $false
    }

    if (!$force -and ($old_version -eq $version)) {
        if (!$quiet) {
            warn "The latest version of '$app' ($version) is already installed."
        }
        return
    }
    if (!$version) {
        # installed from a custom bucket/no longer supported
        error "No manifest available for '$app'."
        return
    }

    Write-Host "Updating '$app' ($old_version -> $version)"

    # region Workaround
    # Workaround for https://github.com/ScoopInstaller/Scoop/issues/2220 until install is refactored
    # Remove and replace whole region after proper fix
    Write-Host "Downloading new version"
    if (Test-Aria2Enabled) {
        dl_with_cache_aria2 $app $version $manifest $architecture $cachedir $manifest.cookie $true $check_hash
    } else {
        $urls = script:url $manifest $architecture

        foreach ($url in $urls) {
            dl_with_cache $app $version $url $null $manifest.cookie $true

            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $source = fullpath (cache_path $app $version $url)
                $ok, $err = check_hash $source $manifest_hash $(show_app $app $bucket)

                if (!$ok) {
                    error $err
                    if (Test-Path $source) {
                        # rm cached file
                        Remove-Item -force $source
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket "hash check failed")
                }
            }
        }
    }
    # There is no need to check hash again while installing
    $check_hash = $false
    # endregion Workaround

    $dir = versiondir $app $old_version $global
    $persist_dir = persistdir $app $global

    #region Workaround for #2952
    if (test_running_process $app $global) {
        return
    }
    #endregion Workaround for #2952

    Write-Host "Uninstalling '$app' ($old_version)"
    run_uninstaller $old_manifest $architecture $dir
    rm_shims $app $old_manifest $global $architecture
    env_rm_path $old_manifest $dir $global $architecture
    env_rm $old_manifest $global $architecture

    # If a junction was used during install, that will have been used
    # as the reference directory. Otherwise it will just be the version
    # directory.
    $refdir = unlink_current $dir

    if ($force -and ($old_version -eq $version)) {
        if (!(Test-Path "$dir/../_$version.old")) {
            Move-Item "$dir" "$dir/../_$version.old"
        } else {
            $i = 1
            While (Test-Path "$dir/../_$version.old($i)") {
                $i++
            }
            Move-Item "$dir" "$dir/../_$version.old($i)"
        }
    }

    if ($bucket) {
        # add bucket name it was installed from
        $app = "$bucket/$app"
    }
    if ($install.url) {
        # use the url of the install json if the application was installed through url
        $app = $install.url
    }

    if ($independent) {
        install_app $app $architecture $global $suggested $use_cache $check_hash
    } else {
        # Also add missing dependencies
        $apps = @(Get-Dependency $app $architecture) -ne $app
        ensure_none_failed $apps
        $apps.Where({ !(installed $_) }) + $app | ForEach-Object { install_app $_ $architecture $global $suggested $use_cache $check_hash }
    }
}

if (-not ($apps -or $all)) {
    if ($global) {
        error 'scoop update: --global is invalid when <app> is not specified.'
        exit 1
    }
    if (!$use_cache) {
        error 'scoop update: --no-cache is invalid when <app> is not specified.'
        exit 1
    }
    update_scoop
} else {
    if ($global -and !(is_admin)) {
        'ERROR: You need admin rights to update global apps.'; exit 1
    }

    if (is_scoop_outdated) {
        update_scoop
    }
    $outdated = @()
    $apps_param = $apps

    if ($apps_param -eq '*' -or $all) {
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        $apps = Confirm-InstallationStatus $apps_param -Global:$global
    }
    if ($apps) {
        $apps | ForEach-Object {
            ($app, $global) = $_
            $status = app_status $app $global
            if ($status.installed -and ($force -or $status.outdated)) {
                if (!$status.hold) {
                    $outdated += applist $app $global
                    Write-Host -f yellow ("$app`: $($status.version) -> $($status.latest_version){0}" -f ('', ' (global)')[$global])
                } else {
                    warn "'$app' is held to version $($status.version)"
                }
            } elseif ($apps_param -ne '*') {
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
            Write-Host -f Green "Latest versions for all apps are installed! For more information try 'scoop status'"
        } else {
            Write-Host -f DarkCyan "Updating one outdated app:"
        }
    }

    $suggested = @{};
    # $outdated is a list of ($app, $global) tuples
    $outdated | ForEach-Object { update @_ $quiet $independent $suggested $use_cache $check_hash }
}

exit 0
