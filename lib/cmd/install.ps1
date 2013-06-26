# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app, $architecture)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ..\manifest.ps1)
. (resolve ..\install.ps1)
. (resolve ..\help.ps1)

switch($architecture) {
	'' { $architecture = architecture }
	{ @('32bit','64bit') -contains $_ } { }
	default { abort "invalid architecture: '$architecture'"}
}

if(!$app) { "ERROR: <app> missing"; my_usage; exit }

$manifest = manifest $app
if(!$manifest) { abort "couldn't find manifest for $app" }

$version = $manifest.version
if(!$version) { abort "manifest doesn't specify a version" }
if($version -match '[^\w\.\-_]') { abort "manifest version has unsupported character '$($matches[0])'" }

if(installed $app) { abort "$app is already installed. Use 'scoop update' to install a new version."}

$dir = ensure (versiondir $app $version)

# save manifest for uninstall
cp (manifest_path $app) "$dir\manifest.json"
@{ 'architecture' = $architecture} | convertto-json | out-file "$dir\install.json"

# can be multiple urls: if there are, then msi or installer should go last,
# so that $fname is set properly
$urls = @(url $manifest $architecture)

$fname = $null

foreach($url in $urls) {
	$fname = split-path $url -leaf

	dl_with_cache $app $version $url "$dir\$fname"

	check_hash "$dir\$fname" $url $manifest $architecture

	# unzip
	if($fname -match '\.zip') {
		# use tmp directory and copy so we can prevent 'folder merge' errors when multiple URLs
		$null = mkdir "$dir\_scoop_unzip"
		unzip "$dir\$fname" "$dir\_scoop_unzip" $manifest.unzip_folder
		cp "$dir\_scoop_unzip\*" "$dir" -recurse -force
		rm -r -force "$dir\_scoop_unzip"
		rm "$dir\$fname"
	}
}

# MSI or other installer
$msi = msi $manifest $architecture
$installer = installer $manifest $architecture

if($msi -or $installer) {
	$exe = $null; $arg = $null; $rmfile = $null
	
	if($msi) { # msi
		$rmfile = $msifile = "$dir\$(coalesce $msi.file "$fname")"
		if(!(is_in_dir $dir $msifile)) {
			abort "error in manifest: MSI file $msifile is outside the app directory"
		}
		if(!($msi.code)) { abort "error in manifest: couldn't find MSI code"}
		$exe = 'msiexec'
		$arg = @("/I `"$msifile`"", '/qb-!', "TARGETDIR=`"$dir`"")
	} elseif($installer) { # other installer
		$rmfile = $exe = "$dir\$(coalesce $installer.exe "$fname")"
		if(!(is_in_dir $dir $exe)) {
			abort "error in manifest: installer $exe is outside the app directory"
		}
		$arg = args $installer.args $dir
	}
	
	$installed = run $exe $arg "running installer..."
	if(!$installed) {
		abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
	}
	rm "$rmfile"
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

 # post-install commands
$manifest.post_install | ? {$_ } | % {
 	iex $_
 }

success "$app was installed successfully!"