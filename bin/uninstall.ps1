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
    $version = latest_version $app
    $dir = versiondir $app $version
    $manifest = installed_manifest $app $version
    $install = install_info $app $version
    $architecture = $install.architecture

    echo "uninstalling $app"
    run_uninstaller $manifest $architecture $dir
    rm_user_path $manifest $dir
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