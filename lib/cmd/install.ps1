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
if(!$manifest) { abort "couldn't find manifest for $app" }

$version = $manifest.version
if(!$version) { abort "manifest doesn't specify a version" }

if(installed $app) { abort "$app is already installed. Use 'scoop update' to install a new version."}

$dir = ensure (versiondir $app $version)

$url = url $manifest
$fname = coalesce $manifest.url_filename (split-path $url -leaf)

if(is_local $url) {
	echo "copying $url..."
	cp $url "$dir\$fname"
} else {
	echo "downloading $url..."
	dl $url "$dir\$fname"
}

# save manifest for uninstall
cp (manifest_path $app) "$dir\manifest.json"

function rm_dl { rm "$dir\$fname"}

# unzip
if($fname -match '\.zip') {
	unzip "$dir\$fname" $dir $manifest.unzip_folder
	rm_dl
}

# installer
if($manifest.msi -or $manifest.installer) {
	$exe = $null; $arg = $null;
	
	if($manifest.msi) { # msi
		$msifile = "$dir\$(coalesce $manifest.msi.file "$fname")"
		if(!(is_in_dir $dir $msifile)) {
			abort "error in manifest: MSI file $msifile is outside the app directory"
		}
		if(!(msi_code $manifest)) { abort "error in manifest: couldn't find MSI code"}
		$exe = 'msiexec'
		$arg = @("/I `"$msifile`"", '/qb-!', "TARGETDIR=`"$dir`"")
	} elseif($manifest.installer) { # other installer
		$exe = "$dir\$(coalesce $manifest.installer.exe "$fname")"
		if(!(is_in_dir $dir $exe)) {
			abort "error in manifest: installer $exe is outside the app directory"
		}
		$arg = args $manifest.installer.args $dir
	}
	
	$installed = run $exe $arg "installing..."
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

# add to path
$manifest.add_path | ? { $_ } | % {
	$path_dir = "$dir\$($_)"
	if(!(is_in_dir $dir $path_dir)) {
		abort "error in manifest: add_to_path '$_' is outside the app directory"
	}
	ensure_in_path $path_dir
}

success "$app was installed successfully!"