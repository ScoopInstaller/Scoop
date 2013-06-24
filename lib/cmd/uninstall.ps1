# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help.ps1)
. (resolve ../install.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "$app isn't installed" }

$versions = @(versions $app)
$version = $versions[-1]
"uninstalling $app $version"

$dir = versiondir $app $version
$manifest = installed_manifest $app $version

if($manifest.msi -or $manifest.uninstaller) {
	$exe = $null; $arg = $null;

	if($manifest.msi) {
		$code = msi_code $manifest
		$exe = "msiexec"; $arg = @("/x $code", '/quiet'); 
	} elseif($manifest.uninstaller) {
		$exe = "$dir\$($manifest.uninstaller.exe)"
		$arg = args $manifest.uninstaller.args
		if(!(is_in_dir $dir $exe)) {
			warn "error in manifest: installer $exe is outside the app directory, skipping"
			$exe = $null;
		} elseif(!(test-path $exe)) {
			warn "uninstaller $($manifest.uninstaller.exe) is missing, skipping"
			$exe = $null;
		}
	}

	if($exe) {
		$uninstalled = run $exe $arg "running uninstaller..."
		if(!$uninstalled) { abort "uninstallation aborted."	}
	}
}

# remove bin stubs
$manifest.bin | ?{ $_ -ne $null } | % {
	$stub = "$bindir\$(strip_ext(fname $_)).ps1"
	if(!(test-path $stub)) { # handle no stub from failed install
		warn "stub for $_ is missing, skipping"
	} else {
		echo "removing stub for $_"
		rm $stub
	}	
}

# remove from path
$manifest.add_path | ? { $_ } | % {
	$path_dir = "$dir\$($_)"
	remove_from_path $path_dir
}

try {
	rm -r $dir -ea stop -force
} catch {
	abort "couldn't remove $(friendly_path $dir): it may be in use"
}

if(@(versions $app).length -eq 0) {
	rm -r (appdir $app) -ea stop -force
}


success "$app was uninstalled"