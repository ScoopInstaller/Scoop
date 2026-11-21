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
                    if ($filePath -match "^$([regex]::Escape($innerBucketLoc)).*\.json$") {
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
                    if ($filePath -match "^$([regex]::Escape($innerBucketLoc)).*\.json$") {
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
    if ($removed) { Remove-ShimFromManifest $ctx.app @{ bin = $removed } $ctx.global $ctx.architecture }

    # the shortcut is edited in place, its removed arguments and icons would stay
    $shortcuts = @(arch_specific 'shortcuts' $old_manifest $ctx.architecture | Where-Object { $_ -ne $null })
    if ($shortcuts) { rm_startmenu_shortcuts @{ shortcuts = $shortcuts } $ctx.global $ctx.architecture }

    $current = "$(Split-Path $ctx.dir)\current"
    # a renamed app keeps none of its paths: every one of them names the old folder
    $paths = if ($ctx.renamed_to) {
        @()
    } else {
        @(env_paths $new_manifest $current $ctx.persist_dir $ctx.new_architecture)
    }
    # the old paths were expanded with the version directory, a nightly manifest keeps the name 'nightly'
    $version = Split-Path $ctx.dir -Leaf
    if (get_config NO_JUNCTION) {
        # without junctions the paths point at the version directory
        $removed = @(env_paths $old_manifest $ctx.dir $ctx.persist_dir $ctx.architecture)
    } else {
        $removed = @(env_paths $old_manifest $current $ctx.persist_dir $ctx.architecture) | Where-Object { $_ -notin $paths }
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

function restore_app($ctx, $old_manifest, $old_version, $backup) {
    if ($ctx.renamed_to -and (Test-Path -LiteralPath (appdir $ctx.renamed_to $ctx.global))) {
        $renamed_from = $ctx.renamed_to
        $ctx.renamed_to = $null
        try {
            Move-Item -LiteralPath (appdir $renamed_from $ctx.global) -Destination (appdir $ctx.app $ctx.global) -ErrorAction Stop
            if (Test-Path -LiteralPath (persistdir $renamed_from $ctx.global)) {
                Move-Item -LiteralPath (persistdir $renamed_from $ctx.global) -Destination $ctx.persist_dir -ErrorAction Stop
            }
            move_app_cache $renamed_from $ctx.app
        } catch {
            warn "'$($ctx.app)' could not be moved back: $($_.Exception.Message)"
        }
    }
    # the old manifest expands $version, which still names the failed update
    $version = $old_version
    if ($backup -and (Test-Path $backup)) {
        try {
            # the backup would land inside the recreated directory
            if (Test-Path $ctx.dir) { Remove-Item $ctx.dir -Recurse -Force -ErrorAction Stop }
            Move-Item $backup $ctx.dir -ErrorAction Stop
        } catch {
            warn "'$($ctx.app)' ($old_version) could not be restored: $($_.Exception.Message)"
            return
        }
    }
    if (installed_manifest $ctx.app $old_version $ctx.global) {
        Write-Host "Restoring '$($ctx.app)' ($old_version)"
        $original_dir = $ctx.dir
        try {
            $dir = link_current $ctx.dir
            link_app $old_manifest $dir $original_dir $ctx.persist_dir $ctx.global $ctx.architecture
        } catch {
            warn "'$($ctx.app)' ($old_version) was restored, but its links could not be recreated: $($_.Exception.Message)"
        }
    } else {
        warn "'$($ctx.app)' ($old_version) cannot be restored; its files were removed by the uninstaller."
    }
}

function move_app_cache($app, $new_app) {
    $pattern = '^' + [regex]::Escape($app) + '#'
    Get-ChildItem -LiteralPath $cachedir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } |
        ForEach-Object { Rename-Item -LiteralPath $_.FullName -NewName ($_.Name -replace $pattern, "$new_app#") }
}

function update_app($app, $global, $force = $false, $quiet = $false, $independent, $suggested, $failed, $use_cache = $true, $check_hash = $true) {
    $app_key = if ($global) { "$app (global)" } else { $app }
    $app_name = $app
    $unlinked = $false
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
    $target = $null
    $moved_persist = $false
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
                }
            }
            if ($blocked) {
                $failed[$app_key] = "skipped: moved to '$target'; $blocked"
                return
            }
            if ($renamed) { $renamed_to = $target_app }
            $bucket = $target_bucket
            $manifest = $target_manifest
            $url = $null
        }
    }

    $version = $manifest.version
    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $quiet
        $check_hash = $false
    }

    if (!$force -and !$renamed_to -and ($old_version -eq $version)) {
        if ($target -and !$renamed_to) {
            save_install_info @{ architecture = $architecture; url = $url; bucket = $bucket } (versiondir $app $old_version $global)
            Write-Host "Migrated '$app' to bucket '$bucket'."
        } elseif (!$quiet) {
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
    if ($version -match '[^\w\.\-\+_]') {
        error "Manifest version has unsupported character '$($matches[0])'."
        $failed[$app_key] = 'invalid manifest'
        return
    }

    if ($target -and !$renamed_to) {
        Write-Host "Migrating '$app' to bucket '$bucket'"
    }
    Write-Host "Updating '$app' ($old_version -> $version)"

    # the new version may be built for another architecture than the installed one
    $new_architecture = Get-SupportedArchitecture $manifest $architecture

    $failed_deps = failed_deps $manifest $failed
    if ($failed_deps.Count -gt 0) {
        error "'$app' depends on $($failed_deps -join ', '), which failed."
        $failed[$app_key] = "dependency failed: $($failed_deps -join ', ')"
        return
    }

    if (!(get_config 'download_while_running' $true) -and (test_running_process $app $global)) {
        Write-Host 'Running process detected, skip updating.'
        $failed[$app_key] = 'blocked: running process'
        return
    }

    # a version that is still installed is switched to here, the same way 'scoop reset' does
    $forced = ($force -or $renamed_to) -and $old_version -eq $version
    $dir = versiondir $app $old_version $global
    $persist_dir = persistdir $app $global
    $ctx = [PSCustomObject]@{
        app              = $app
        dir              = $dir
        persist_dir      = $persist_dir
        global           = $global
        architecture     = $architecture
        new_architecture = $new_architecture
        renamed_to       = $renamed_to
    }
    $installed_dir = versiondir $app $version $global
    $retained = !(Test-Path -LiteralPath "$installed_dir\.scoop-extracted") -and
    ((Test-Path -LiteralPath "$installed_dir\scoop-manifest.json") -or (Test-Path -LiteralPath "$installed_dir\manifest.json"))
    if (!$forced -and $retained -and !$renamed_to) {
        if (test_running_process $app $global) {
            Write-Host 'Running process detected, skip updating.'
            $failed[$app_key] = 'blocked: running process'
            return
        }

        $installed = installed_manifest $app $version $global
        $installed_architecture = Format-ArchitectureString (install_info $app $version $global).architecture
        if (-not $independent) {
            # the dependencies of the version that is switched to, not the ones the manifest has now
            $deps = @($installed.depends | Where-Object { $_ -and !(installed $_) } | ForEach-Object { Get-Dependency $_ $installed_architecture } | Where-Object { !(installed $_) } | Select-Object -Unique)
            $deps | ForEach-Object { install_app $_ $installed_architecture $global $suggested $failed $use_cache $check_hash }
            $failed_deps = failed_deps $installed $failed
            if ($failed_deps.Count -gt 0) {
                error "'$app' depends on $($failed_deps -join ', '), which failed."
                $failed[$app_key] = "dependency failed: $($failed_deps -join ', ')"
                return
            }
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
            restore_app $ctx $old_manifest $old_version
        }
        return
    }

    # switching to a retained version downloads nothing, so only a new installation must support the architecture
    if ($null -eq $new_architecture) {
        error "'$app' doesn't support current architecture!"
        $failed[$app_key] = 'unsupported architecture'
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
    $prepared = prepare_app $app $new_architecture $global $manifest $bucket $version $use_cache $check_hash $stage
    if (!$prepared) {
        $failed[$app_key] = 'download failed'
        return
    }

    try {
        Invoke-HookScript -HookType 'pre_uninstall' -Manifest $old_manifest -Arch $architecture

        if (test_running_process $app $global) {
            Write-Host 'Running process detected, skip updating.'
            $failed[$app_key] = 'blocked: running process, the new version was downloaded'
            return
        }

        Write-Host "Uninstalling '$app' ($old_version)"
        if (!(Invoke-Installer -Path $dir -Manifest $old_manifest -ProcessorArchitecture $architecture -Global:$global -Uninstall)) {
            $failed[$app_key] = 'uninstaller failed'
            return
        }
        $unlinked = $true
        remove_obsolete_wiring $ctx $old_manifest $manifest

        $backup = $null
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
            $backup = $new_backup
        }

        Invoke-HookScript -HookType 'post_uninstall' -Manifest $old_manifest -Arch $architecture

        if ($renamed_to) {
            Write-Host "Migrating '$app_key' to '$target'"
            $old_persist = persistdir $app $global
            if (Test-Path -LiteralPath $old_persist) {
                Move-Item -LiteralPath $old_persist -Destination (persistdir $renamed_to $global) -ErrorAction Stop
                $moved_persist = $true
            }
            try {
                Move-Item -LiteralPath (appdir $app $global) -Destination (appdir $renamed_to $global) -ErrorAction Stop
            } catch {
                if ($moved_persist) { Move-Item -LiteralPath (persistdir $renamed_to $global) -Destination $old_persist -ErrorAction Stop }
                throw
            }
            move_app_cache $app $renamed_to
            $prepared.dir = Join-Path (appdir $renamed_to $global) (Split-Path $prepared.dir -Leaf)
            $app = $app_name = $renamed_to
            $app_key = if ($global) { "$app (global)" } else { $app }
            $dir = versiondir $app $old_version $global
        }

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

        $failed_deps = failed_deps $manifest $failed
        if ($failed_deps.Count -gt 0) {
            error "'$app_name' depends on $($failed_deps -join ', '), which failed."
            $failed[$app_key] = "dependency failed: $($failed_deps -join ', ')"
        } else {
            if ($forced) {
                Move-Item $prepared.dir $dir -ErrorAction Stop
                $prepared.dir = $dir
            }
            install_version $app_name $manifest $version $new_architecture $global $bucket $url $suggested $failed $prepared.dir $prepared.fname
            if ($renamed_to -and !$failed.ContainsKey($app_key)) {
                foreach ($version_dir in @(Get-ChildItem -LiteralPath (appdir $renamed_to $global) -Directory -Force | Where-Object { $_.Name -notmatch '^(current|_)' })) {
                    $info = install_info $renamed_to $version_dir.Name $global
                    if (!$info -or !$info.bucket) { continue }
                    $record = Join-Path $version_dir.FullName 'scoop-install.json'
                    $stamp = if (Test-Path -LiteralPath $record) { (Get-Item -LiteralPath $record).LastWriteTimeUtc } else { $version_dir.LastWriteTimeUtc }
                    save_install_info @{ architecture = $info.architecture; url = $info.url; bucket = $bucket } $version_dir.FullName
                    # version order is the records' write time, so restoring one must keep it
                    (Get-Item -LiteralPath $record).LastWriteTimeUtc = $stamp
                }
                $shim_dir = shimdir $global
                @(arch_specific 'bin' $old_manifest $architecture) | Where-Object { $_ } | ForEach-Object {
                    $target, $name, $null = Get-ShimDefinition $_
                    # not Remove-Shim: it also deletes an active command that now belongs to another app
                    @('', '.shim', '.cmd', '.ps1') | ForEach-Object {
                        $saved = "$shim_dir\$name" + $_ + ".$($ctx.app)"
                        if (Test-Path -LiteralPath $saved -PathType Leaf) { Remove-Item -LiteralPath $saved -Force }
                    }
                }
            }
        }
        if ($failed.ContainsKey($app_key)) {
            restore_app $ctx $old_manifest $old_version $backup
        }
    } catch {
        $failed[$app_key] = $_.Exception.Message
        error $_.Exception.Message
        if ($unlinked) {
            restore_app $ctx $old_manifest $old_version $backup
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
