# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help.ps1)
. (resolve ../install.ps1)
. (resolve ../versions.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "$app isn't installed" }

$versions = @(versions $app)
$version = $versions[-1]
"uninstalling $app $version"

$dir = versiondir $app $version
$manifest = installed_manifest $app $version
$install = install_info $app $version
$architecture = $install.architecture

run_uninstaller $manifest $architecture $dir
rm_bin_stubs $manifest
rm_user_path $manifest $dir

try {
	rm -r $dir -ea stop -force
} catch {
	abort "couldn't remove $(friendly_path $dir): it may be in use"
}

if(@(versions $app).length -eq 0) {
	rm -r (appdir $app) -ea stop -force
}


success "$app was uninstalled"