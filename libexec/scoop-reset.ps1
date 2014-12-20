# Usage: scoop reset <app>
# Summary: Reset an app to resolve conflicts
# Help: Used to resolve conflicts in favor of a particular app. For example,
# if you've installed 'python' and 'python27', you can use 'scoop reset' to switch between
# using one or the other.
#
# Options:
#   --global, -g  update a globally installed app
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\versions.ps1"

$opt, $app, $err = getopt $args 'global'
if($err) { "scoop reset: $err"; exit 1 }
$global = $opt.g -or $opt.global

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }
if($global -and !(is_admin)) {
  'ERROR: you need admin rights to reset global apps'; exit 1
}

if(!(installed $app $global)) { abort "$app isn't installed" }

$version = current_version $app $global
"resetting $app ($version)"

$dir = resolve-path (versiondir $app $version $global)
$manifest = installed_manifest $app $version $global

create_shims $manifest $dir $global
env_add_path $manifest $dir $global
env_set $manifest $dir@ $global