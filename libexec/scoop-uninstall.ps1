# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$psscriptroot\..\lib\core.ps1"
. (relpath ..\lib\manifest.ps1)
. (relpath ..\lib\help.ps1)
. (relpath ..\lib\install.ps1)
. (relpath ..\lib\versions.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "$app isn't installed" }

$versions = @(versions $app)
$version = $versions[-1]
"uninstalling $app ($version)"

$dir = versiondir $app $version
$manifest = installed_manifest $app $version
$install = install_info $app $version
$architecture = $install.architecture

run_uninstaller $manifest $architecture $dir
rm_shims $manifest
rm_env_path $manifest $dir
rm_env $manifest

try { rm -r $dir -ea stop -force }
catch { abort "couldn't remove $(friendly_path $dir): it may be in use" }

# remove older versions
$old = @(versions $app)
foreach($oldver in $old) {
	"removing older version, $oldver"
	$dir = versiondir $app $oldver
	try { rm -r -force -ea stop $dir }
	catch { abort "couldn't remove $(friendly_path $dir): it may be in use" }
}

if(@(versions $app).length -eq 0) {
	$appdir = appdir $app
	try {
		# if last install failed, the directory seems to be locked and this
		# will throw an error about the directory not existing
		rm -r $appdir -ea stop -force
	} catch {
		if((test-path $appdir)) { throw } # only throw if the dir still exists
	}
}

success "$app was uninstalled"
exit 0