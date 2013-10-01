# Usage: scoop update [app] [options]
# Summary: Update an app, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update [app]' installs a new version of that app, if there is one.
#
# Options:
#   --global, -g  update a globally installed app
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"

$opt, $app, $err = getopt $args 'g' 'global'
if($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global

if(!$app) {
	if($global) {
		"scoop update: --global is invalid when <app> not specified"; exit 1
	}
	# update scoop
	$tempdir = versiondir 'scoop' 'update'
	$currentdir = versiondir 'scoop' 'current'

	if(test-path $tempdir) {
		try { rm -r $tempdir -ea stop -force } catch { abort "couldn't remove $tempdir`: it may be in use" }
	}
	$tempdir = ensure $tempdir
	$currentdir = fullpath $currentdir

	$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
	$zipfile = "$tempdir\scoop.zip"
	echo 'downloading...'
	dl $zipurl $zipfile

	echo 'extracting...'
	unzip $zipfile $tempdir 'scoop-master'
	rm $zipfile

	echo 'replacing files...'
	$null = robocopy $tempdir $currentdir /mir /njh /njs /nfl /ndl
	rm -r -force $tempdir -ea stop

	$null > "$currentdir\last_updated" # save update timestamp
	ensure_scoop_in_path

	shim "$currentdir\bin\scoop.ps1" $false

	@(buckets) | % {
		"updating $_ bucket..."
		$git = try { gcm git -ea stop } catch { $null }
		if(!$git) { warn "git is required for buckets. run 'scoop install git'." }
		else {
			pushd (bucketdir $_)
			git pull -q
			popd
		}
	}
	success 'scoop was updated successfully!'
} else {
	# update app
	if(!(installed $app $global)) {
		if(installed $app (!$global)) {
			function wh($g) { if($g) { "globally" } else { "for your account" } }
			write-host "$app isn't installed $(wh $global), but it is installed $(wh (!$global))" -f darkred
			"try updating $(if($global) { 'without' } else { 'with' }) the --global (or -g) flag instead"
			exit 1
		} else {
			abort "$app isn't installed"
		}
	}

	if($global -and !(is_admin)) {
		'ERROR: you need admin rights to update global apps'; exit 1
	}

	$old_version = current_version $app $global
	$manifest = installed_manifest $app $old_version $global
	$install = install_info $app $old_version $global

	# re-use architecture, bucket and url from first install
	$architecture = $install.architecture
	$bucket = $install.bucket
	$url = $install.url

	$version = latest_version $app $bucket $url

	if($old_version -eq $version) {
		"the latest version of $app ($version) is already installed."
		"run 'scoop update' to check for new versions."
		exit 1
	}
	if(!$version) { abort "no manifest available for $app" } # installed from a custom bucket/no longer supported

	"updating $app ($old_version -> $version)"

	$dir = versiondir $app $old_version	$global

	"uninstalling $app ($old_version)"
	run_uninstaller $manifest $architecture $dir
	rm_shims $manifest $global
	# note: keep the old dir in case it contains user files

	"installing $app ($version)"
	$dir = ensure (versiondir $app $version $global)

	$manifest = manifest $app $bucket $url
		
	# save info for uninstall
	save_installed_manifest $app $bucket $dir $url
	save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

	$fname = dl_urls $app $version $manifest $architecture $dir
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir
	create_shims $manifest $dir $global
	env_add_path $manifest $dir $global
	env_set $manifest $dir $global
	post_install $manifest

	success "$app was updated from $old_version to $version"

	show_notes $manifest
}

exit 0