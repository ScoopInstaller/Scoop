# Usage: scoop install <app> [url]
# Summary: Install an app
# Help: e.g. To install an app from your local Scoop bucket:
#      scoop install git
#
# To install an app from a manifest provided at a URL:
#      scoop install runat https://raw.github.com/lukesampson/scoop/master/bucket/runat.json
param($app, $url, $architecture)

. "$psscriptroot\..\lib\core.ps1"
. (relpath ..\lib\manifest.ps1)
. (relpath ..\lib\install.ps1)
. (relpath ..\lib\versions.ps1)
. (relpath ..\lib\help.ps1)

switch($architecture) {
	'' { $architecture = architecture }
	{ @('32bit','64bit') -contains $_ } { }
	default { abort "invalid architecture: '$architecture'"}
}

if(!$app) { "ERROR: <app> missing"; my_usage; exit }

$manifest = manifest $app $url
if(!$manifest) { abort "couldn't find the manifest for $app$(if($url) { " at the URL $url" })" }

$version = $manifest.version
if(!$version) { abort "manifest doesn't specify a version" }
if($version -match '[^\w\.\-_]') { abort "manifest version has unsupported character '$($matches[0])'" }

if(installed $app) { abort "$app is already installed. Use 'scoop update $app' to install a new version."}

$dir = ensure (versiondir $app $version)

# save info for uninstall
save_installed_manifest $app $dir $url
save_install_info @{ 'architecture' = $architecture; 'url' = $url } $dir

$fname = dl_urls $app $version $manifest $architecture $dir
run_installer $fname $manifest $architecture $dir
ensure_install_dir_not_in_path $dir
create_shims $manifest $dir
add_user_path $manifest $dir
post_install $manifest

success "$app $version was installed successfully!"

show_notes $manifest

exit 0