$modulesdir = "$scoopdir\modules"

function install_psmodule ($manifest,$dir,$global) {
  $psmodule = $manifest.psmodule
  if (!$psmodule) { return }

  if ($global) {
    abort "Installing PowerShell modules globally is not implemented!"
  }

  $modulesdir = ensure $modulesdir
  ensure_in_psmodulepath $modulesdir $global

  $module_name = $psmodule.Name
  if (!$module_name) {
    abort "Invalid manifest: The 'name' property is missing from 'psmodule'."
    return
  }

  $linkfrom = "$modulesdir\$module_name"
  Write-Host "Installing PowerShell module '$module_name'"

  Write-Host "Linking $(friendly_path $linkfrom) => $(friendly_path $dir)"

  if (Test-Path $linkfrom) {
    warn "$(friendly_path $linkfrom) already exists. It will be replaced."
    & "$env:COMSPEC" /c "rmdir $linkfrom"
  }

  & "$env:COMSPEC" /c "mklink /j $linkfrom $dir" | Out-Null
}

function uninstall_psmodule ($manifest,$dir,$global) {
  $psmodule = $manifest.psmodule
  if (!$psmodule) { return }

  $module_name = $psmodule.Name
  Write-Host "Uninstalling PowerShell module '$module_name'."

  $linkfrom = "$modulesdir\$module_name"
  if (Test-Path $linkfrom) {
    Write-Host "Removing $(friendly_path $linkfrom)"
    $linkfrom = Resolve-Path $linkfrom
    & "$env:COMSPEC" /c "rmdir $linkfrom"
  }
}

function ensure_in_psmodulepath ($dir,$global) {
  $path = env 'psmodulepath' $global
  $dir = fullpath $dir
  if ($path -notmatch [regex]::Escape($dir)) {
    Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) PowerShell module path."

    env 'psmodulepath' $global "$dir;$path" # for future sessions...
    $env:psmodulepath = "$dir;$env:psmodulepath" # for this session
  }
}
