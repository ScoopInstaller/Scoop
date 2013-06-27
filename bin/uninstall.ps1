. "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"
. (resolve ..\lib\install.ps1)
. (resolve ..\lib\versions.ps1)
. (resolve ..\lib\manifest.ps1)

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