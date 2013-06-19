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

if(installed $app) { abort "'$app' is already installed. use 'scoop update' to install a new version."}

$dir = ensure (versiondir $app $version)

$url = url $manifest
echo "downloading $url..."
$fname = split-path $url -leaf
dl $url "$dir\$fname"

function rm_dl { rm "$dir\$fname"}

# unzip
if($fname -match '\.zip') {
	unzip "$dir\$fname" $dir
	rm_dl
}

# run installer
if($manifest.installer) {
	$exe = "$dir\$(coalesce $manifest.installer.exe "$fname")"
	if(!(is_in_dir $dir $exe)) {
		abort "error in manifest: installer $exe is outside the app directory"
	}
	$installed = run $exe (args $manifest.installer.args $dir) "installing..."
	if(!$installed) {
		abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
	}
	rm_dl
}

# create bin stubs
$manifest.bin | ?{ $_ -ne $null } | % {
	echo "creating stub for $_ in ~\appdata\local\bin"

	# check valid bin
	$bin = "$dir\$_"
	if(!(is_in_dir $dir $bin)) {
		abort "error in manifest: bin '$_' is outside the app directory"
	}
	if(!(test-path $bin)) { abort "can't stub $_`: file doesn't exist"}

	stub "$dir\$_"
}

success "$app was installed successfully!"