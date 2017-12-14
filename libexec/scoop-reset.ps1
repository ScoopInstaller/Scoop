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
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\shortcuts.ps1"

reset_aliases

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

$appWithVersion = get_app_with_version $app
$app            = $appWithVersion.app;
$version        = $appWithVersion.version;


if(!(installed $app)) { abort "'$app' isn't installed" }

if ($version -eq 'latest') {
    $version = current_version $app
}

$manifest = installed_manifest $app $version
# if this is null we know the version they're resetting to
# is not installed
if ($manifest -eq $null) {
    abort "'$app ($version)' isn't installed"
}

"Resetting $app ($version)."

$dir = resolve-path (versiondir $app $version)

$install = install_info $app $version
$architecture = $install.architecture

$dir = link_current $dir
create_shims $manifest $dir $false $architecture
create_startmenu_shortcuts $manifest $dir $false
env_add_path $manifest $dir
env_set $manifest $dir

exit 0
