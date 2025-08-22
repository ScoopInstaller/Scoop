function uninstall_app {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$app,
        [Parameter(Mandatory = $true)]
        [bool]$global,
        [Parameter(Mandatory = $true)]
        [bool]$purge
    )

    $version = Select-CurrentVersion -AppName $app -Global:$global
    $appDir = appdir $app $global
    if ($version) {
        Write-Host "Uninstalling '$app' ($version)."

        $dir = versiondir $app $version $global
        $persist_dir = persistdir $app $global

        $manifest = installed_manifest $app $version $global
        $install = install_info $app $version $global
        $architecture = $install.architecture

        Invoke-HookScript -HookType 'pre_uninstall' -Manifest $manifest -Arch $architecture

        # region Workaround for #2952
        # https://github.com/ScoopInstaller/Scoop/issues/2952
        if (test_running_process $app $global) {
            return $false
        }
        # endregion Workaround for #2952

        try {
            Test-Path $dir -ErrorAction Stop | Out-Null
        } catch [UnauthorizedAccessException] {
            error "Access denied: $dir. You might need to restart."
            return $false
        }

        Invoke-Installer -Path $dir -Manifest $manifest -ProcessorArchitecture $architecture -Global:$global -Uninstall
        rm_shims $app $manifest $global $architecture
        rm_startmenu_shortcuts $manifest $global $architecture

        # If a junction was used during install, that will have been used
        # as the reference directory. Otherwise it will just be the version
        # directory.
        $refdir = unlink_current $dir

        uninstall_psmodule $manifest $refdir $global

        env_rm_path $manifest $refdir $global $architecture
        env_rm $manifest $global $architecture

        try {
            # unlink all potential old link before doing recursive Remove-Item
            unlink_persist_data $manifest $dir
            Remove-Item $dir -Recurse -Force -ErrorAction Stop
        } catch {
            if (Test-Path $dir) {
                error "Couldn't remove '$(friendly_path $dir)'; it may be in use."
                return $false
            }
        }

        Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -Arch $architecture
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
            return $false
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
            Remove-Item $appDir -Recurse -Force -ErrorAction Stop
        } catch {
            if ((Test-Path $appDir)) { throw } # only throw if the dir still exists
        }
    }

    # purge persistant data
    if ($purge) {
        Write-Host 'Removing persisted data.'
        $persist_dir = persistdir $app $global

        if (Test-Path $persist_dir) {
            try {
                Remove-Item $persist_dir -Recurse -Force -ErrorAction Stop
            } catch {
                error "Couldn't remove '$(friendly_path $persist_dir)'; it may be in use."
                return $false
            }
        }
    }

    success "'$app' was uninstalled."
    return $true
}
