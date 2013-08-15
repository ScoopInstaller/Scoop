. "$psscriptroot\..\lib\core.ps1"
. (relpath ..\lib\install.ps1)
. (relpath ..\lib\versions.ps1)
. (relpath ..\lib\manifest.ps1)

warn 'this will uninstall scoop and all the programs that have been installed with scoop!'
$yn = read-host 'are you sure? (yN)'
if($yn -notlike 'y*') { exit }

# run uninstallers if necessary
installed_apps | % {
	$app = $_
	$version = current_version $app
	$dir = versiondir $app $version
	$manifest = installed_manifest $app $version
	$install = install_info $app $version
	$architecture = $install.architecture

	echo "uninstalling $app"
	run_uninstaller $manifest $architecture $dir
	rm_env_path $manifest $dir
	rm_env $manifest
}

if(test-path $scoopdir) {
	try {
		rm -r -force $scoopdir -ea stop
	} catch {
		abort "couldn't remove $(friendly_path $scoopdir): $_"
	}
}

remove_from_path $shimdir

success "scoop has been uninstalled"