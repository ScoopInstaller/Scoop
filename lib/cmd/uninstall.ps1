# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help_comments.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "'$app' isn't installed" }

# todo: run uninstaller from manifest
# todo: remove bin stubs from manifest

$appdir = appdir $app
try {
	rm -r $appdir -ea stop
} catch {
	abort "couldn't remove $(friendly_path $appdir): it may be in use"
}

success "$app was uninstalled"