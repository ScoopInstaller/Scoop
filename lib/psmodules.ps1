function install_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    $targetdir = ensure (modulesdir $global)

    ensure_in_psmodulepath $targetdir $global

    $module_name = $psmodule.name
    if (!$module_name) {
        abort "Invalid manifest: The 'name' property is missing from 'psmodule'."
    }

    $linkfrom = "$targetdir\$module_name"
    Write-Host "Installing PowerShell module '$module_name'"

    Write-Host "Linking $(friendly_path $linkfrom) => $(friendly_path $dir)"

    if (Test-Path $linkfrom) {
        warn "$(friendly_path $linkfrom) already exists. It will be replaced."
        Remove-Item -Path $linkfrom -Force -Recurse -ErrorAction SilentlyContinue
    }

    New-DirectoryJunction $linkfrom $dir | Out-Null
}

function uninstall_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if (!$psmodule) { return }

    $module_name = $psmodule.name
    Write-Host "Uninstalling PowerShell module '$module_name'."

    $targetdir = modulesdir $global

    $linkfrom = "$targetdir\$module_name"
    if (Test-Path $linkfrom) {
        Write-Host "Removing $(friendly_path $linkfrom)"
        $linkfrom = Convert-Path $linkfrom
        Remove-Item -Path $linkfrom -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function ensure_in_psmodulepath($dir, $global) {
    $path = env 'psmodulepath' $global
    if (!$global -and $null -eq $path) {
        $path = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    }
    $dir = fullpath $dir
    if ($path -notmatch [Regex]::Escape($dir)) {
        Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) PowerShell module path."

        env 'psmodulepath' $global "$dir;$path" # for future sessions...
        $env:psmodulepath = "$dir;$env:psmodulepath" # for this session
    }
}
