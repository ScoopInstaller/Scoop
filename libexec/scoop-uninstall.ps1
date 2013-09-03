# Usage: scoop uninstall <app> [options]
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
#
# Options:
#   -g, --global   uninstall a globally installed app
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\opts.ps1"

# options
$opt, $app, $err = getopt $args 'g' 'global'
if($err) { "scoop uninstall: $err"; exit 1 }
$global = $opt.g -or $opt.global

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app $global)) { abort "$app isn't installed" }

if($global -and !(is_admin)) {
	'ERROR: you need admin rights to install global apps'; exit 1
}
if($app -eq 'scoop') {
    & "$psscriptroot\..\bin\uninstall.ps1"; exit
}

$version = current_version $app $global
"uninstalling $app ($version)"

$dir = versiondir $app $version $global
$manifest = installed_manifest $app $version $global
$install = install_info $app $version $global
$architecture = $install.architecture

run_uninstaller $manifest $architecture $dir
rm_shims $manifest $global
env_rm_path $manifest $dir $global
env_rm $manifest $global

try { rm -r $dir -ea stop -force }
catch { abort "couldn't remove $(friendly_path $dir): it may be in use" }

# remove older versions
$old = @(versions $app $global)
foreach($oldver in $old) {
	"removing older version, $oldver"
	$dir = versiondir $app $oldver $global
	try { rm -r -force -ea stop $dir }
	catch { abort "couldn't remove $(friendly_path $dir): it may be in use" }
}

if(@(versions $app).length -eq 0) {
	$appdir = appdir $app $global
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