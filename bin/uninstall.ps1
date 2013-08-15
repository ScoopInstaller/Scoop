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

# try deleting app directories one-by-one except for scoop, in case uninstall fails
# and we need to run `scoop uninstall scoop` again
$errors = $false
gci $appdir | ? name -ne 'scoop' | % {
    $dir = $_
    try {
        rm -r -force $dir -ea stop
    } catch {
        $errors = $true
        warn "couldn't remove $(friendly_path $dir): $_.exception"
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

remove_from_path $shimdir

success "scoop has been uninstalled"