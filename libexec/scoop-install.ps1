# Usage: scoop install <app> [options]
# Summary: Install apps
# Help: e.g. The usual way to install an app (uses your local 'buckets'):
#      scoop install git
#
# To install an app from a manifest at a URL:
#      scoop install https://raw.github.com/lukesampson/scoop/master/bucket/runat.json
#
# To install an app from a manifest on your computer
#      scoop install \path\to\app.json
#
# When installing from your computer, you can leave the .json extension off if you like.
#
# Options:
#   -a, --arch <32bit|64bit>  use the specified architecture, if the app supports it
#   -g, --global              install the app globally

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"

function install($app, $architecture, $global) {
	$app, $manifest, $bucket, $url = locate $app

	if(!$manifest) {
		abort "couldn't find manifest for $app$(if($url) { " at the URL $url" })"
	}

	$version = $manifest.version
	if(!$version) { abort "manifest doesn't specify a version" }
	if($version -match '[^\w\.\-_]') {
		abort "manifest version has unsupported character '$($matches[0])'"
	}

	if(installed $app $global) {
		$global_flag = $null; if($global){$global_flag = ' --global'}

		$version = @(versions $app $global)[-1]
		if(!(install_info $app $version $global)) {
			abort "it looks like a previous installation of $app failed.`nrun 'scoop uninstall $app$global_flag' before retrying the install."
		}
		abort "$app ($version) is already installed.`nuse 'scoop update $app$global_flag' to install a new version."
	}

	if(!(7zip_installed)) {
		if(requires_7zip $manifest $architecture) {
			abort "7zip is required to install this app. please run 'scoop install 7zip'"
		}
	}

	"installing $app ($version)"

	$dir = ensure (versiondir $app $version $global)

	$fname = dl_urls $app $version $manifest $architecture $dir
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir $global
	create_shims $manifest $dir $global
	if($global) { ensure_scoop_in_path $global } # can assume local scoop is in path
	env_add_path $manifest $dir $global
	env_set $manifest $dir $global
	post_install $manifest

	# save info for uninstall
	save_installed_manifest $app $bucket $dir $url
	save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

	success "$app ($version) was installed successfully!"

	show_notes $manifest
}

$opt, $apps, $err = getopt $args 'ga:' 'global', 'arch='
if($err) { "scoop install: $err"; exit 1 }

$global = $opt.g -or $opt.global
$architecture = $opt.a + $opt.arch

switch($architecture) {
	'' { $architecture = architecture }
	{ @('32bit','64bit') -contains $_ } { }
	default { abort "invalid architecture: '$architecture'"}
}

if(!$apps) { 'ERROR: <app> missing'; my_usage; exit 1 }

if($global -and !(is_admin)) {
	'ERROR: you need admin rights to install global apps'; exit 1
}

$apps | % { install $_ $architecture $global }

exit 0