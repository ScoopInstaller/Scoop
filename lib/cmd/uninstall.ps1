# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help.ps1)
. (resolve ../install.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "'$app' isn't installed" }

$appdir = appdir $app
$manifest = manifest $app

if($manifest.uninstaller) {
	$exe = "$appdir\$($manifest.uninstaller.exe)";
	if(test-path $exe) {
		$uninstalled = run $exe (args $manifest.uninstaller.args) "uninstalling..."
		if(!$uninstalled) { abort "uninstallation aborted."	}
	} else {
		warn "uninstaller $($manifest.uninstaller.exe) not found, skipping"
	}
}

# remove bin stubs
$manifest.bin | ?{ $_ -ne $null } | % {
	$stub = "$bindir\$(strip_ext(fname $_)).ps1"
	if(!(test-path $stub)) { # handle no stub from failed install
		warn "stub for $_ was missing, skipped"
	} else {
		echo "removing stub for $_"
		rm $stub
	}	
}

try {
	rm -r $appdir -ea stop
} catch {
	abort "couldn't remove $(friendly_path $appdir): it may be in use"
}

success "$app was uninstalled"