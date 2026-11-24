function Sync-Scoop {
    [CmdletBinding()]
    Param (
        [Switch]$Log
    )
    # Test if Scoop Core is hold
    if (Test-ScoopCoreOnHold) {
        return
    }

    # check for git
    if (!(Test-GitAvailable)) { abort "Scoop uses Git to update itself. Run 'scoop install git' and try again." }

    # Find current update repository from config
    $configRepo = get_config SCOOP_REPO
    if (!$configRepo) {
        $configRepo = 'https://github.com/ScoopInstaller/Scoop'
        set_config SCOOP_REPO $configRepo | Out-Null
    }

    # Find current update branch from config
    $configBranch = get_config SCOOP_BRANCH
    if (!$configBranch) {
        $configBranch = 'master'
        set_config SCOOP_BRANCH $configBranch | Out-Null
    }

    Write-Host 'Updating Scoop...'
    $currentdir = versiondir 'scoop' 'current'
    $oldShimHash = Get-ShimBodyHash (Get-ShimTemplate)
    if (!(Test-Path "$currentdir\.git")) {
        $newdir = "$currentdir\..\new"
        $olddir = "$currentdir\..\old"

        # get git scoop
        Invoke-Git -ArgumentList @('clone', '-q', $configRepo, '--branch', $configBranch, '--single-branch', $newdir)

        # check if scoop was successful downloaded
        if (!(Test-Path "$newdir\bin\scoop.ps1")) {
            Remove-Item $newdir -Force -Recurse
            abort "Scoop download failed. If this appears several times, try removing SCOOP_REPO by 'scoop config rm SCOOP_REPO'"
        } else {
            # replace non-git scoop with the git version
            try {
                Rename-Item $currentdir 'old' -ErrorAction Stop
                Rename-Item $newdir 'current' -ErrorAction Stop
            } catch {
                Write-Warning $_
                abort "Scoop update failed. Folder in use. Please rename folders $currentdir to ``old`` and $newdir to ``current``."
            }
        }
    } else {
        if (Test-Path "$currentdir\..\old") {
            Remove-Item "$currentdir\..\old" -Recurse -Force -ErrorAction SilentlyContinue
        }

        $previousCommit = Invoke-Git -Path $currentdir -ArgumentList @('rev-parse', 'HEAD')
        $currentRepo = Invoke-Git -Path $currentdir -ArgumentList @('config', 'remote.origin.url')
        $currentBranch = Invoke-Git -Path $currentdir -ArgumentList @('branch')

        $isRepoChanged = !($currentRepo -match $configRepo)
        $isBranchChanged = !($currentBranch -match "\*\s+$configBranch")

        # Stash uncommitted changes
        if (Invoke-Git -Path $currentdir -ArgumentList @('diff', 'HEAD', '--name-only')) {
            if (get_config AUTOSTASH_ON_CONFLICT) {
                warn 'Uncommitted changes detected. Stashing...'
                Invoke-Git -Path $currentdir -ArgumentList @('stash', 'push', '-m', "WIP at $([System.DateTime]::Now.ToString('o'))", '-u', '-q')
            } else {
                warn 'Uncommitted changes detected. Update aborted.'
                return
            }
        }

        # Change remote url if the repo is changed
        if ($isRepoChanged) {
            Invoke-Git -Path $currentdir -ArgumentList @('config', 'remote.origin.url', $configRepo)
        }

        # Fetch and reset local repo if the repo or the branch is changed
        if ($isRepoChanged -or $isBranchChanged) {
            # Reset git fetch refs, so that it can fetch all branches (GH-3368)
            Invoke-Git -Path $currentdir -ArgumentList @('config', 'remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*')
            # fetch remote branch
            Invoke-Git -Path $currentdir -ArgumentList @('fetch', '--force', 'origin', "refs/heads/$configBranch`:refs/remotes/origin/$configBranch", '-q')
            # checkout and track the branch
            Invoke-Git -Path $currentdir -ArgumentList @('checkout', '-B', $configBranch, '-t', "origin/$configBranch", '-q')
            # reset branch HEAD
            Invoke-Git -Path $currentdir -ArgumentList @('reset', '--hard', "origin/$configBranch", '-q')
        } else {
            Invoke-Git -Path $currentdir -ArgumentList @('pull', '--tags', '--force', '-q')
        }

        $res = $lastexitcode
        if ($Log) {
            Invoke-GitLog -Path $currentdir -CommitHash $previousCommit
        }

        if ($res -ne 0) {
            abort 'Update failed.'
        }
    }

    New-Shim "$currentdir\bin\scoop.ps1" $false

    $shimTemplate = Get-ShimTemplate
    # compare shim template hashes and trigger a refresh if needed
    if (!$oldShimHash -or $oldShimHash -ne (Get-ShimBodyHash $shimTemplate)) {
        Update-ShimInstance $shimTemplate
    }
}

function Sync-Bucket {
    Param (
        [Switch]$Log
    )
    Write-Host 'Updating Buckets...'

    if (!(Test-Path (Join-Path (Find-BucketDirectory 'main' -Root) '.git'))) {
        info "Converting 'main' bucket to git repo..."
        $status = rm_bucket 'main'
        if ($status -ne 0) {
            abort "Failed to remove local 'main' bucket."
        }
        $status = add_bucket 'main' (known_bucket_repo 'main')
        if ($status -ne 0) {
            abort "Failed to add remote 'main' bucket."
        }
    }


    $buckets = Get-LocalBucket | ForEach-Object {
        $path = Find-BucketDirectory $_ -Root
        return @{
            name  = $_
            valid = Test-Path (Join-Path $path '.git')
            path  = $path
        }
    }

    $buckets | Where-Object { !$_.valid } | ForEach-Object { Write-Host "'$($_.name)' is not a git repository. Skipped." }

    $updatedFiles = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    $removedFiles = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        # Parallel parameter is available since PowerShell 7
        $buckets | Where-Object { $_.valid } | ForEach-Object -ThrottleLimit 5 -Parallel {
            . "$using:PSScriptRoot\core.ps1"
            . "$using:PSScriptRoot\buckets.ps1"

            $name = $_.name
            $bucketLoc = $_.path
            $innerBucketLoc = Find-BucketDirectory $name

            $previousCommit = Invoke-Git -Path $bucketLoc -ArgumentList @('rev-parse', 'HEAD')
            Invoke-Git -Path $bucketLoc -ArgumentList @('pull', '-q')
            if ($using:Log) {
                Invoke-GitLog -Path $bucketLoc -Name $name -CommitHash $previousCommit
            }
            if (get_config USE_SQLITE_CACHE) {
                Invoke-Git -Path $bucketLoc -ArgumentList @('diff', '--name-status', $previousCommit) | ForEach-Object {
                    $status, $file = $_ -split '\s+', 2
                    $filePath = Join-Path $bucketLoc $file
                    if ($filePath -match "^$([regex]::Escape($innerBucketLoc)).*\.json$" -and $file -ne '.scoop-migrations.json') {
                        switch ($status) {
                            { $_ -in 'A', 'M', 'R' } {
                                [void]($using:updatedFiles).Add($filePath)
                            }
                            'D' {
                                [void]($using:removedFiles).Add([pscustomobject]@{
                                        Name   = ([System.IO.FileInfo]$file).BaseName
                                        Bucket = $name
                                    })
                            }
                        }
                    }
                }
            }
        }
    } else {
        $buckets | Where-Object { $_.valid } | ForEach-Object {
            $name = $_.name
            $bucketLoc = $_.path
            $innerBucketLoc = Find-BucketDirectory $name

            $previousCommit = Invoke-Git -Path $bucketLoc -ArgumentList @('rev-parse', 'HEAD')
            Invoke-Git -Path $bucketLoc -ArgumentList @('pull', '-q')
            if ($Log) {
                Invoke-GitLog -Path $bucketLoc -Name $name -CommitHash $previousCommit
            }
            if (get_config USE_SQLITE_CACHE) {
                Invoke-Git -Path $bucketLoc -ArgumentList @('diff', '--name-status', $previousCommit) | ForEach-Object {
                    $status, $file = $_ -split '\s+', 2
                    $filePath = Join-Path $bucketLoc $file
                    if ($filePath -match "^$([regex]::Escape($innerBucketLoc)).*\.json$" -and $file -ne '.scoop-migrations.json') {
                        switch ($status) {
                            { $_ -in 'A', 'M', 'R' } {
                                [void]($updatedFiles).Add($filePath)
                            }
                            'D' {
                                [void]($removedFiles).Add([pscustomobject]@{
                                        Name   = ([System.IO.FileInfo]$file).BaseName
                                        Bucket = $name
                                    })
                            }
                        }
                    }
                }
            }
        }
    }
    if ((get_config USE_SQLITE_CACHE) -and ($updatedFiles.Count -gt 0 -or $removedFiles.Count -gt 0)) {
        info 'Updating cache...'
        Set-ScoopDB -Path $updatedFiles
        $removedFiles | Remove-ScoopDBItem
    }
}

function remove_obsolete_wiring($ctx, $old_manifest, $new_manifest) {
    # a later uninstall would delete the data through the old persist links
    unlink_persist_data $old_manifest $ctx.dir

    $shim_id = { param($entry) $target, $name, $null = Get-ShimDefinition $entry; "$name$([IO.Path]::GetExtension($target))" }
    $ids = @(arch_specific 'bin' $new_manifest $ctx.new_architecture | Where-Object { $_ -ne $null } | ForEach-Object { & $shim_id $_ })
    $removed = @(arch_specific 'bin' $old_manifest $ctx.architecture | Where-Object { $_ -ne $null } | Where-Object { (& $shim_id $_) -notin $ids })
    if ($removed) {
        # the wiring was created under the name the app was installed as
        $owner = if ($ctx.renamed_from) { $ctx.renamed_from } else { $ctx.app }
        Remove-ShimFromManifest $owner @{ bin = $removed } $ctx.global $ctx.architecture
    }

    # the shortcut is edited in place, its removed arguments and icons would stay
    $shortcuts = @(arch_specific 'shortcuts' $old_manifest $ctx.architecture | Where-Object { $_ -ne $null })
    if ($shortcuts) { rm_startmenu_shortcuts @{ shortcuts = $shortcuts } $ctx.global $ctx.architecture }

    $current = "$(Split-Path $ctx.dir)\current"
    $old_dir = if ($ctx.renamed_from) { versiondir $ctx.renamed_from (Split-Path $ctx.dir -Leaf) $ctx.global } else { $ctx.dir }
    $old_current = "$(Split-Path $old_dir)\current"
    $old_persist_dir = if ($ctx.renamed_from) { persistdir $ctx.renamed_from $ctx.global } else { $ctx.persist_dir }
    $paths = @(env_paths $new_manifest $current $ctx.persist_dir $ctx.new_architecture)
    # the old paths were expanded with the version directory, a nightly manifest keeps the name 'nightly'
    $version = Split-Path $ctx.dir -Leaf
    if (get_config NO_JUNCTION) {
        # without junctions the paths point at the version directory
        $removed = @(env_paths $old_manifest $old_dir $old_persist_dir $ctx.architecture)
    } else {
        $removed = @(env_paths $old_manifest $old_current $old_persist_dir $ctx.architecture) | Where-Object { $_ -notin $paths }
    }
    if ($removed) {
        Remove-Path -Path $removed -Global:$ctx.global
        Remove-Path -Path $removed -TargetEnvVar $scoopPathEnvVar -Global:$ctx.global
    }

    $names = @((arch_specific 'env_set' $new_manifest $ctx.new_architecture).PSObject.Properties.Name)
    $removed = @((arch_specific 'env_set' $old_manifest $ctx.architecture).PSObject.Properties.Name) | Where-Object { $_ -notin $names }
    foreach ($var in $removed) {
        Set-EnvVar -Name $var -Value $null -Global:$ctx.global
        Remove-Item "env:\$var" -ErrorAction SilentlyContinue
    }

    if ($old_manifest.psmodule.name -and $old_manifest.psmodule.name -ne $new_manifest.psmodule.name) {
        uninstall_psmodule $old_manifest $ctx.dir $ctx.global
    }
}

function restore_app($ctx) {
    $old_manifest = $ctx.old_manifest
    $old_version = $ctx.old_version
    $backup = $ctx.backup
    # the backup would land inside the recreated directory
    if ($backup -and (Test-Path $backup)) {
        try {
            if (Test-Path $ctx.dir) { Remove-Item $ctx.dir -Recurse -Force -ErrorAction Stop }
            Move-Item $backup $ctx.dir -ErrorAction Stop
        } catch {
            warn "'$($ctx.app)' ($old_version) could not be restored: $($_.Exception.Message)"
            return
        }
    }
    $app = $ctx.app
    $dir = $ctx.dir
    $persist_dir = $ctx.persist_dir
    if ($ctx.renamed_from -and (Test-Path -LiteralPath (appdir $ctx.app $ctx.global))) {
        # the app goes back to the name it was installed under, so its links work again
        try {
            Move-Item -LiteralPath (appdir $app $ctx.global) -Destination (appdir $ctx.renamed_from $ctx.global) -ErrorAction Stop
            if (Test-Path -LiteralPath $persist_dir) {
                Move-Item -LiteralPath $persist_dir -Destination (persistdir $ctx.renamed_from $ctx.global) -ErrorAction Stop
            }
            move_app_cache $app $ctx.renamed_from
        } catch {
            warn "'$($ctx.renamed_from)' could not be moved back: $($_.Exception.Message)"
        }
        $app = $ctx.renamed_from
        $dir = versiondir $app $old_version $ctx.global
        $persist_dir = persistdir $app $ctx.global
    }
    # the old manifest expands $version, which still names the failed update
    $version = $old_version
    if (installed_manifest $app $old_version $ctx.global) {
        Write-Host "Restoring '$app' ($old_version)"
        $original_dir = $dir
        try {
            $dir = link_current $dir
            link_app $old_manifest $dir $original_dir $persist_dir $ctx.global $ctx.architecture
        } catch {
            warn "'$app' ($old_version) was restored, but its links could not be recreated: $($_.Exception.Message)"
        }
    } else {
        warn "'$app' ($old_version) cannot be restored; its files were removed by the uninstaller."
    }
}

function move_app($app, $new_app, $global, $manifest, $version) {
    $old_persist = persistdir $app $global
    $moved_persist = $false
    if (Test-Path -LiteralPath $old_persist) {
        Move-Item -LiteralPath $old_persist -Destination (persistdir $new_app $global) -ErrorAction Stop
        $moved_persist = $true
    }
    $moved_app = $false
    try {
        Move-Item -LiteralPath (appdir $app $global) -Destination (appdir $new_app $global) -ErrorAction Stop
        $moved_app = $true
        move_app_cache $app $new_app
        if ($moved_persist -and $manifest.persist) {
            # persist_data builds its links from $dir in the caller's scope, and the old uninstall hooks read them there
            $dir = versiondir $new_app $version $global
            unlink_persist_data $manifest $dir
            persist_data $manifest $dir (persistdir $new_app $global)
        }
    } catch {
        if ($moved_app) { Move-Item -LiteralPath (appdir $new_app $global) -Destination (appdir $app $global) -ErrorAction SilentlyContinue }
        if ($moved_persist) { Move-Item -LiteralPath (persistdir $new_app $global) -Destination $old_persist -ErrorAction SilentlyContinue }
        move_app_cache $new_app $app
        throw
    }
}

function move_app_cache($app, $new_app) {
    $pattern = '^' + [regex]::Escape($app) + '#'
    Get-ChildItem -LiteralPath $cachedir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } |
        ForEach-Object {
            # the same download may already be there under the new name
            if (!(Test-Path -LiteralPath (Join-Path $cachedir ($_.Name -replace $pattern, "$new_app#")))) {
                Rename-Item -LiteralPath $_.FullName -NewName ($_.Name -replace $pattern, "$new_app#")
            }
        }
}

function remove_saved_commands($manifest, $owner, $arch, $global) {
    $shim_dir = shimdir $global
    @(arch_specific 'bin' $manifest $arch) | Where-Object { $_ } | ForEach-Object {
        $target, $name, $null = Get-ShimDefinition $_
        # not Remove-Shim: it also deletes an active command that now belongs to another app
        @('', '.shim', '.cmd', '.ps1') | ForEach-Object {
            $saved = "$shim_dir\$name" + $_ + ".$owner"
            if (Test-Path -LiteralPath $saved -PathType Leaf) { Remove-Item -LiteralPath $saved -Force }
        }
    }
}

function save_app_bucket($app, $bucket, $global) {
    foreach ($version_dir in @(Get-ChildItem -LiteralPath (appdir $app $global) -Directory -Force | Where-Object { $_.Name -notmatch '^(current|_)' })) {
        $info = install_info $app $version_dir.Name $global
        if (!$info -or !$info.bucket) { continue }
        $fields = @{}
        $info.PSObject.Properties | ForEach-Object { $fields[$_.Name] = $_.Value }
        $fields['bucket'] = $bucket
        save_install_info $fields $version_dir.FullName
    }
}

function switch_version($ctx) {
    $app = $ctx.app
    $app_key = $ctx.app_key
    $global = $ctx.global
    $version = $ctx.version
    $old_version = $ctx.old_version
    $installed_dir = $ctx.installed_dir
    $old_manifest = $ctx.old_manifest
    $independent = $ctx.independent
    $suggested = $ctx.suggested
    $failed = $ctx.failed
    $use_cache = $ctx.use_cache
    $check_hash = $ctx.check_hash
    if (block_running_app $app $global $app_key $failed 'updating') { return }

    $installed = installed_manifest $app $version $global
    $installed_architecture = Format-ArchitectureString (install_info $app $version $global).architecture
    if (-not $independent) {
        # the dependencies of the version that is switched to, not the ones the manifest has now
        $deps = @($installed.depends | Where-Object { $_ -and !(installed $_) } | ForEach-Object { Get-Dependency $_ $installed_architecture } | Where-Object { !(installed $_) } | Select-Object -Unique)
        $deps | ForEach-Object { install_app $_ $installed_architecture $global $suggested $failed $use_cache $check_hash }
        if (report_failed_deps $installed $app $app_key $failed) { return }
    }
    $ctx.new_architecture = $installed_architecture
    try {
        Write-Host "Switching '$app' ($old_version -> $version)"
        remove_obsolete_wiring $ctx $old_manifest $installed
        $dir = link_current $installed_dir
        link_app $installed $dir $installed_dir $ctx.persist_dir $global $installed_architecture
        success "'$app' was switched to the installed $version."
    } catch {
        $failed[$app_key] = $_.Exception.Message
        error $_.Exception.Message
        # drop what the failed switch linked, then rebuild the links of the old version
        $installed_ctx = [PSCustomObject]@{
            app              = $app
            dir              = $installed_dir
            persist_dir      = $ctx.persist_dir
            global           = $global
            architecture     = $installed_architecture
            new_architecture = $ctx.architecture
        }
        try {
            remove_obsolete_wiring $installed_ctx $installed $old_manifest
        } catch {
            Write-Verbose $_.Exception.Message
        }
        # the switch already took the current link down, so the old links need rebuilding
        $ctx.unlinked = $true
    }
}

function replace_version($ctx) {
    $app = $app_name = $ctx.app
    $app_key = $ctx.app_key
    $global = $ctx.global
    $dir = $ctx.dir
    $architecture = $ctx.architecture
    $new_architecture = $ctx.new_architecture
    $old_version = $ctx.old_version
    $old_manifest = $ctx.old_manifest
    $manifest = $ctx.manifest
    $version = $ctx.version
    $bucket = $ctx.bucket
    $url = $ctx.url
    $install = $ctx.install
    $pin_broken = $ctx.pin_broken
    $forced = $ctx.forced
    $prepared = $ctx.prepared
    $independent = $ctx.independent
    $suggested = $ctx.suggested
    $failed = $ctx.failed
    $use_cache = $ctx.use_cache
    $check_hash = $ctx.check_hash
    $ctx.unlinked = $false
    try {
        # only this attempt's failure counts: an earlier entry is restored below
        $earlier_failure = $failed[$app_key]
        $failed.Remove($app_key)
        uninstall_version $app $old_manifest $old_version $architecture $global $failed $dir 'updating' 'running process, the new version was downloaded'
        if ($failed.ContainsKey($app_key)) { return }
        if ($null -ne $earlier_failure) { $failed[$app_key] = $earlier_failure }
        $ctx.unlinked = $true
        remove_obsolete_wiring $ctx $old_manifest $manifest

        $ctx.backup = $null
        if ($forced) {
            $new_backup = "$dir/../_$version.old"
            if (Test-Path $new_backup) {
                $i = 1
                While (Test-Path "$new_backup($i)") {
                    $i++
                }
                $new_backup = "$new_backup($i)"
            }
            Move-Item $dir $new_backup -ErrorAction Stop
            $ctx.backup = $new_backup
        }

        Invoke-HookScript -HookType 'post_uninstall' -Manifest $old_manifest -Arch $architecture

        if ($bucket) {
            # add bucket name it was installed from
            $app = "$bucket/$app"
        }
        if ($install.url -and (!$pin_broken -or !$bucket)) {
            # use the url of the install json if the application was installed through url
            $app = $install.url
        }

        if (-not $independent) {
            # Also add missing dependencies
            $apps = @(Get-Dependency $app $architecture) -ne $app
            $apps.Where({ !(installed $_) }) | ForEach-Object { install_app $_ $architecture $global $suggested $failed $use_cache $check_hash }
        }

        if (!(report_failed_deps $manifest $app_name $app_key $failed)) {
            if ($forced) {
                Move-Item $prepared.dir $dir -ErrorAction Stop
                $prepared.dir = $dir
            }
            install_version $app_name $manifest $version $new_architecture $global $bucket $url $suggested $failed $prepared.dir $prepared.fname
        }
    } catch {
        $failed[$app_key] = $_.Exception.Message
        error $_.Exception.Message
    }
}

function update_app($app, $global, $force = $false, $quiet = $false, $independent, $suggested, $failed, $use_cache = $true, $check_hash = $true) {
    $app_key = app_key $app $global
    $requested_key = $app_key
    $app_name = $app
    $old_version = Select-CurrentVersion -AppName $app -Global:$global
    $old_manifest = installed_manifest $app $old_version $global
    $install = install_info $app $old_version $global

    # re-use architecture, bucket and url from first install
    $architecture = Format-ArchitectureString $install.architecture
    $bucket = $install.bucket
    $url = $install.url

    # -f on an @version pin re-resolves against the bucket HEAD
    $pin_broken = $force -and $null -eq $bucket -and ($url -eq (usermanifest $app))
    if ($pin_broken) {
        $scanned, $bucket = Find-AppBucket $app
        if ($scanned) {
            $manifest = $scanned
            $url = $null
        } else {
            $manifest = manifest $app $null $url
        }
    } else {
        if ($null -eq $bucket -and !$url) { $bucket = 'main' }
        $manifest = manifest $app $bucket $url
    }

    $renamed_to = $null
    $renamed_from = $null
    $target = $null
    if (!$manifest -and $bucket) {
        $target_app, $target_manifest, $target_bucket, $target_url = Get-Manifest "$bucket/$app"
        if ($target_app -ne $app -or $target_bucket -ine $bucket) {
            $target = if ($target_bucket) { "$target_bucket/$target_app" } else { $target_app }
            $renamed = $target_app -ne $app
            $blocked = if (!$target_manifest) {
                Get-BucketAddHint $target_bucket
            } elseif ($renamed) {
                if (installed $target_app $global) {
                    "'$target_app' is already installed"
                } elseif (Test-Path -LiteralPath (appdir $target_app $global)) {
                    "'$(appdir $target_app $global)' already exists"
                } elseif (Test-Path -LiteralPath (persistdir $target_app $global)) {
                    "'$(persistdir $target_app $global)' already holds saved data"
                } elseif (test_running_process $app $global) {
                    'the app is running'
                }
            }
            if ($blocked) {
                $failed[$app_key] = "skipped: moved to '$target'; $blocked"
                return
            }
            if ($renamed) {
                $renamed_to = $target_app
            } else {
                save_app_bucket $app $target_bucket $global
                Write-Host "Migrating '$app_key' to bucket '$target_bucket'"
            }
            $bucket = $target_bucket
            $manifest = $target_manifest
            $url = $null
        }
    }

    $version = $manifest.version
    if ($version -eq 'nightly') {
        $version = nightly_version $quiet
        $check_hash = $false
    }

    if (!$force -and !$renamed_to -and ($old_version -eq $version)) {
        if (!$quiet -and !$target) {
            warn "The latest version of '$app' ($version) is already installed."
        }
        return
    }
    if (!$version) {
        # installed from a custom bucket/no longer supported
        error "No manifest available for '$app'."
        $failed[$app_key] = 'no manifest available'
        return
    }
    if (!(test_version_chars $version)) {
        $failed[$app_key] = 'invalid manifest'
        return
    }

    Write-Host "Updating '$app' ($old_version -> $version)"

    # the new version may be built for another architecture than the installed one
    $new_architecture = Get-SupportedArchitecture $manifest $architecture

    if (report_failed_deps $manifest $app $app_key $failed) { return }

    if (!(get_config 'download_while_running' $true) -and (block_running_app $app $global $app_key $failed 'updating')) { return }

    if ($renamed_to) {
        # The rename is the boundary: above it the app keeps its old name, below it the flow is the original one.
        Write-Host "Migrating '$app_key' to '$target'"
        move_app $app $renamed_to $global $old_manifest $old_version
        $renamed_from = $app
        $app = $app_name = $renamed_to
        $app_key = app_key $app $global
    }

    # a version that is still installed is switched to here, the same way 'scoop reset' does
    $forced = ($force -or $renamed_to) -and $old_version -eq $version
    $dir = versiondir $app $old_version $global
    $persist_dir = persistdir $app $global
    $installed_dir = versiondir $app $version $global
    $ctx = [PSCustomObject]@{
        app              = $app
        app_key          = $app_key
        global           = $global
        dir              = $dir
        persist_dir      = $persist_dir
        installed_dir    = $installed_dir
        architecture     = $architecture
        new_architecture = $new_architecture
        old_version      = $old_version
        old_manifest     = $old_manifest
        version          = $version
        manifest         = $manifest
        bucket           = $bucket
        url              = $url
        install          = $install
        pin_broken       = $pin_broken
        forced           = $forced
        prepared         = $null
        unlinked         = $false
        backup           = $null
        independent      = $independent
        suggested        = $suggested
        failed           = $failed
        use_cache        = $use_cache
        check_hash       = $check_hash
        renamed_from     = $renamed_from
    }
    $retained = !(Test-Path -LiteralPath "$installed_dir\.scoop-extracted") -and
    ((Test-Path -LiteralPath "$installed_dir\scoop-manifest.json") -or (Test-Path -LiteralPath "$installed_dir\manifest.json"))
    # whatever exit the flow takes, a migration is rolled back unless it reached a successful end
    $done = $false
    try {
        if (!$forced -and $retained) {
            switch_version $ctx
            $done = !$failed.ContainsKey($app_key)
            return
        }

        # switching to a retained version downloads nothing, so only a new installation must support the architecture
        if ($null -eq $new_architecture) {
            error "'$app' doesn't support current architecture!"
            $failed[$requested_key] = 'unsupported architecture'
            return
        }

        if (-not $independent) {
            $helpers = Get-InstallationHelper $manifest $new_architecture
            $needed = @($helpers | ForEach-Object { Get-Dependency $_ $new_architecture } | Select-Object -Unique)
            $needed | Where-Object { !(installed $_) } | ForEach-Object {
                install_app $_ $new_architecture $global $suggested $failed $use_cache $check_hash
            }
        }

        $stage = $null
        if ($forced) {
            $stage = versiondir $app "_$version.new" $global
            Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
        # download and extract the new version first, so a broken archive cannot leave the app uninstalled
        $ctx.prepared = prepare_app $app $new_architecture $global $manifest $bucket $version $use_cache $check_hash $stage
        if (!$ctx.prepared) {
            $failed[$requested_key] = 'download failed'
            return
        }

        replace_version $ctx
        $done = !$failed.ContainsKey($app_key)
    } finally {
        if (!$done -and ($renamed_from -or $ctx.unlinked)) {
            restore_app $ctx
        } elseif ($done -and $target) {
            save_app_bucket $app_name $bucket $global
            if ($renamed_to) { remove_saved_commands $old_manifest $renamed_from $architecture $global }
        }
    }
}

function update_apps($apps, $force, $quiet, $independent, $suggested, $failed, $use_cache = $true, $check_hash = $true) {
    $apps | ForEach-Object {
        $current = $_
        try {
            update_app @current $force $quiet $independent $suggested $failed $use_cache $check_hash
        } catch {
            $key = if ($current[1]) { "$($current[0]) (global)" } else { $current[0] }
            $failed[$key] = $_.Exception.Message
            error $_.Exception.Message
        }
    }
}
