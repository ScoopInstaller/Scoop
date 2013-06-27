# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app, $architecture)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ..\manifest.ps1)
. (resolve ..\install.ps1)
. (resolve ..\versions.ps1)
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

# save info for uninstall
save_installed_manifest $app $dir
save_install_info @{ 'architecture' = $architecture } $dir

$fname = dl_urls $app $version $manifest $architecture $dir
run_installer $fname $manifest $architecture $dir
create_bin_stubs $manifest $dir
add_user_path $manifest $dir
post_install $manifest

success "$app $version was installed successfully!"

show_notes $manifest