# Usage: scoop update [app]
# Summary: Update an app, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update [app]' installs a new version of that app, if there is one.
param($app)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"

if(!$app) { 
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
	if(!(installed $app)) { abort "$app isn't installed" }

	$old_version = current_version $app
	$manifest = installed_manifest $app $old_version
	$install = install_info $app $old_version

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

	$dir = versiondir $app $old_version	

	echo "uninstalling $old_version"
	run_uninstaller $manifest $architecture $dir
	rm_shims $manifest $false
	# note: keep the old dir in case in contains user files

	$dir = ensure (versiondir $app $version)

	$manifest = manifest $app $bucket $url
		
	# save info for uninstall
	save_installed_manifest $app $bucket $dir $url
	save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

	$fname = dl_urls $app $version $manifest $architecture $dir
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir
	create_shims $manifest $dir $false
	env_add_path $manifest $dir
	env_set $manifest $dir
	post_install $manifest

	success "$app was updated from $old_version to $version"

	show_notes $manifest
}

exit 0