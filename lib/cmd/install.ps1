# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ..\manifest.ps1)
. (resolve ..\install.ps1)
. (resolve ..\help.ps1)

if(!$app) { "ERROR: <app> missing"; my_usage; exit }

$manifest = manifest $app
if(!$manifest) { abort "couldn't find manifest for '$app'" }

$version = $manifest.version
if(!$version) { abort "manifest doesn't specify a version" }

if(installed $app $version) { abort "'$app' is already installed"}

$appdir = appdir $app $version
mkdir $appdir > $null
$appdir = resolve-path $appdir
$delete_dl_file = $false;

$url = url $manifest
echo "downloading $url..."
$fname = split-path $url -leaf
dl $url "$appdir\$fname"

# unzip
if($fname -match '\.zip') {
	unzip "$appdir\$fname" $appdir
	$delete_dl_file = $true
}

# run installer
if($manifest.installer) {
	$exe = "$appdir\$(coalesce $manifest.installer.exe "$fname")"
	if(!(is_in_dir $appdir $exe)) {
		abort "error in manifest: installer $exe is outside the app directory"
	}
	$installed = run $exe (args $manifest.installer.args) "installing..."
	if(!$installed) {
		abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
	}
	$delete_dl_file = $true
}

if($delete_dl_file) {
	rm "$appdir\$fname"
}

# create bin stubs
$manifest.bin | ?{ $_ -ne $null } | % {
	echo "creating stub for $_ in ~\appdata\local\bin"

	# check valid bin
	$bin = "$appdir\$_"
	if(!(is_in_dir $appdir $bin)) {
		abort "error in manifest: bin '$_' is outside the app directory"
	}
	if(!(test-path $bin)) { abort "can't stub $_`: file doesn't exist"}

	stub "$appdir\$_"
}

success "$app was succesfully installed"