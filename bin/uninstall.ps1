. "$psscriptroot\..\lib\core.ps1"
. (relpath ..\lib\install.ps1)
. (relpath ..\lib\versions.ps1)
. (relpath ..\lib\manifest.ps1)

warn 'this will uninstall scoop and all the programs that have been installed with scoop!'
$yn = read-host 'are you sure? (yN)'
if($yn -notlike 'y*') { exit }

$errors = $false
# run uninstallation for each app if necessary, continuing if there's
# a problem deleting a directory (which is quite likely)
installed_apps | % {
	$app = $_
	$version = current_version $app
	$dir = versiondir $app $version
	$manifest = installed_manifest $app $version
	$install = install_info $app $version
	$architecture = $install.architecture

	echo "uninstalling $app"
	run_uninstaller $manifest $architecture $dir
	rm_shims $manifest $false
	env_rm_path $manifest $dir
	env_rm $manifest

	$appdir = appdir $app
	try {
		rm -r -force $appdir -ea stop
	} catch {
		$errors = $true
		warn "couldn't remove $(friendly_path $appdir): $_.exception"
	}
}

if($errors) {
	abort "not all apps could be deleted. try again or restart"
}

try {
	rm -r -force $scoopdir -ea stop
} catch {
	abort "couldn't remove $(friendly_path $scoopdir): $_"
}

remove_from_path (shimdir $false)

success "scoop has been uninstalled"