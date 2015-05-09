# Usage: scoop reset <app>
# Summary: Reset an app to resolve conflicts
# Help: Used to resolve conflicts in favor of a particular app. For example,
# if you've installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
param($app)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\versions.ps1"

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if ($app -eq "scoop") {
  "resetting scoop"

  if(!(test-path ~/.bashrc)) {
    'creating ~/.bashrc'
    new-item -type file ~/.bashrc | out-null
  }
  if (!(get-content ~/.bashrc | select-string 'alias scoop' -quiet)) {
    'creating bash alias for scoop...'
    'alias scoop="powershell scoop.ps1"' | out-file ~/.bashrc -en oem -append
  }
  else {
    'bash alias for scoop already exists... skipping...'
  }
} 
else {
  if(!(installed $app)) { abort "$app isn't installed" }

  $version = current_version $app
  "resetting $app ($version)"

  $dir = resolve-path (versiondir $app $version)
  $manifest = installed_manifest $app $version

  create_shims $manifest $dir $false
  env_add_path $manifest $dir
  env_set $manifest $dir
}