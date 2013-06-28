# Usage: scoop update [app]
# Summary: Update an app, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update [app]' installs a new version of that app, if there is one.
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ..\install.ps1)
. (resolve ..\manifest.ps1)
. (resolve ..\versions.ps1)

if(!$app) { 
	# update scoop
	$tempdir = versiondir 'scoop' 'update'
	$currentdir = versiondir 'scoop' 'current'

	if(test-path $tempdir) {
		try { rm -r $tempdir -ea stop -force } catch { abort "couldn't remove $tempdir`: it may be in use" }
	}
	$tempdir = ensure $tempdir

	$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
	$zipfile = "$tempdir\scoop.zip"
	echo 'downloading...'
	dl $zipurl $zipfile

	echo 'extracting...'
	unzip $zipfile $tempdir 'scoop-master'
	rm $zipfile

	echo 'replacing files..'
	rm -r -force $currentdir -ea stop
	rni $tempdir 'current' -ea stop

	ensure_scoop_in_path
	success 'scoop was updated successfully!'
} else {
	# update app
	if(!(installed $app)) { abort "$app isn't installed" }

	$old_version = current_version $app
	$manifest = installed_manifest $app $old_version
	$install = install_info $app $old_version

	# re-use architecture and url from first install
	$architecture = $install.architecture
	$url = $install.url

	$version = latest_version $app $url

	if($old_version -eq $version) { abort "$app $version is already installed. run 'scoop update' to check for new versions." }
	if(!$version) { abort "no manifest available for $app" } # installed from a custom bucket/no longer supported

	$dir = versiondir $app $old_version	

	echo "uninstalling $old_version"
	run_uninstaller $manifest $architecture $dir
	rm_shims $manifest
	# note: keep the old dir in case in contains user files

	$dir = ensure (versiondir $app $version)
	$manifest = manifest $app $url

	# save info for uninstall
	save_installed_manifest $app $dir
	save_install_info @{ 'architecture' = $architecture; 'url' = $url } $dir

	$fname = dl_urls $app $version $manifest $architecture $dir
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir
	create_shims $manifest $dir
	add_user_path $manifest $dir
	post_install $manifest

	success "$app was updated from $old_version to $version"

	show_notes $manifest

}