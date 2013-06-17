# Usage: scoop uninstall <app>
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help_comments.ps1)

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

if(!(installed $app)) { abort "'$app' isn't installed" }

$appdir = appdir $app
$manifest = manifest $app

if($manifest.uninstaller) {
	$arguments = $manifest.uninstaller.args
	$a = @()
	if($arguments) { $arguments | % { $a += (format $_ @{'appdir'=$appdir}) } }

	write-host "uninstalling..." -nonewline
	try {
		start-process "$appdir\$($manifest.uninstaller.exe)" -ea 0 -wait -arg $a
	} catch { throw }
	write-host "done"
}

# remove bin stubs from manifest
$manifest.bin | ?{ $_ -ne $null } | % {
	echo "removing stub for $_"
	rm "$bindir\$(strip_ext(fname $_)).ps1"
}

try {
	rm -r $appdir -ea stop
} catch {
	abort "couldn't remove $(friendly_path $appdir): it may be in use"
}

success "$app was uninstalled"