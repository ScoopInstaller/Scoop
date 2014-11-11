# Usage: scoop info <app>
# Summary: Shows a short description of apps
# Help: 'scoop info <app>' displays a short description of the specified app.
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"

$opt, $apps, $err = getopt $args 'g' 'global'
if($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global

function scoop_info() {
	"Scoop is a command-line installer for windows."
	""
	"Scoop installs programs from the command line with a minimal amount of friction. It tries to eliminate things like:"
	"* Permission popup windows"
	"* GUI wizard-style installers"
	"* Path pollution from installing lots of programs"
	"* Unexpected side-effects from installing and uninstalling programs"
	"* The need to find and install dependencies"
	"* The need to perform extra setup steps to get a working program"

	""
	$count = 0
	"buckets:"
	@(buckets) | % {
		"  $_"
		$count += 1
	}
	if($count -eq 0) {
		"  none"
	}

	""
	$tempdir = versiondir 'scoop' 'update'
	$currentdir = versiondir 'scoop' 'current'

	if(test-path $tempdir) {
		try { rm -r $tempdir -ea stop -force } catch { abort "couldn't remove $tempdir`: it may be in use" }
	}
	$tempdir = ensure $tempdir
	$currentdir = fullpath $currentdir

	$timestamp = "$(versiondir 'scoop' 'current')\last_updated"
	if(test-path $timestamp) {
		$last_update = [io.file]::getlastwritetime((resolve-path $timestamp))
		"scoop was last updated $(timeago($last_update))"
	} else {
		"scoop has not been updated.."
	}

	#success 'done.'
}

function show_info($app, $global) {
	$cur_version = current_version $app $global
	$cur_manifest = installed_manifest $app $cur_version $global
	$install = install_info $app $cur_version $global
	$manifest = (manifest $app $install.bucket $install.url)

	"$app ($cur_version; " + $install.architecture + ")"
	if($manifest.description.length -ne 0) {
		""
		$manifest.description
	}

	""
	$dir = versiondir $app $cur_version	$global
	"located at $dir"

	# "uninstalling $app ($cur_version)"
	# run_uninstaller $cur_manifest $install.architecture $dir
	# rm_shims $cur_manifest $global
	# env_rm_path $cur_manifest $dir $global
	# env_rm $cur_manifest $global
	# # note: keep the old dir in case it contains user files

	# "installing $app ($version)"
	# $dir = ensure (versiondir $app $version $global)

	# # save info for uninstall
	# save_installed_manifest $app $install.bucket $dir $install.url
	# save_install_info @{ 'architecture' = $install.architecture; 'url' = $install.url; 'bucket' = $install.bucket } $dir

	# $fname = dl_urls $app $version $manifest $install.architecture $dir
	# unpack_inno $fname $manifest $dir
	# pre_install $manifest
	# run_installer $fname $manifest $install.architecture $dir
	# ensure_install_dir_not_in_path $dir
	# create_shims $manifest $dir $global
	# env_add_path $manifest $dir $global
	# env_set $manifest $dir $global
	# post_install $manifest


	# check dependencies
	""
	"dependencies:"
	$count = 0
	$deps = @(deps $app $install.architecture)
	$deps | % {
		"  $_ $install.architecture $global"
		$count += 1
	}
	if($count -eq 0) {
		"  none"
	}

	# success "$app was updated from $cur_version to $version"

	#show_notes $manifest
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
	return ,@($apps |% { ,@($_, $global) })
}

if(!$apps) {
	scoop_info
} else {
	if($apps -eq '*') {
		$apps = applist (installed_apps $false) $false
		$apps += applist (installed_apps $true) $true
	} else {
		$apps = applist $apps $global
	}

	# $apps is now a list of ($app, $global) tuples
	$apps | % { show_info @_ }
}

exit 0