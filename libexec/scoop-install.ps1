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
#   -arch 32bit|64bit   use the specified architecture, if the app supports it
#   -global             install the app globally

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\help.ps1"

function parse_args($a) {
	$apps = @(); $arch = $null; $global = $false

	for($i = 0; $i -lt $a.length; $i++) {
		$arg = $a[$i]
		if($arg.startswith('-')) {
			switch($arg) {
				'-arch' {
					if($a.length -gt $i + 1) { $arch = $a[$i++] }
					else { write-host '-arch parameter requires a value'; exit 1 }
				}
				'-global' {
					$global = $true
				}
				default {
					write-host "unrecognised parameter: $arg"; exit 1
				}
			}
		} else {
			$apps += $arg
		}
	}

	$apps, $arch, $global
}

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
		$global_flag = $null; if($global){$global_flag = ' -global'}

		$version = @(versions $app)[-1]
		if(!(install_info $app $version)) {
			abort "it looks like a previous installation of $app failed.`nrun 'scoop uninstall $app$global_flag' before retrying the install."
		}
		abort "$app ($version) is already installed.`nuse 'scoop update $app$global_flag' to install a new version."
	}

	# check 7zip installed if required
	if(!(7zip_installed)) {
		foreach($dlurl in @($manifest.url)) {
			if(requires_7zip $dlurl) {
				abort "7zip is required to install this app. please run 'scoop install 7zip'"
			}
		}
	}

	$dir = ensure (versiondir $app $version)

	$fname = dl_urls $app $version $manifest $architecture $dir
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir
	create_shims $manifest $dir $global
	env_add_path $manifest $dir
	env_set $manifest $dir
	post_install $manifest

	# save info for uninstall
	save_installed_manifest $app $bucket $dir $url
	save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

	success "$app ($version) was installed successfully!"

	show_notes $manifest
}

$apps, $architecture, $global = parse_args $args

switch($architecture) {
	'' { $architecture = architecture }
	{ @('32bit','64bit') -contains $_ } { }
	default { abort "invalid architecture: '$architecture'"}
}

if(!$apps) { 'ERROR: <app> missing'; my_usage; exit 1 }

if($global -and !(is_admin)) {
	'ERROR: admin rights required to install global apps'; exit 1
}

$apps | % { install $_ $architecture $global }

exit 0