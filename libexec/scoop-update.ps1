# Usage: scoop update <app> [options]
# Summary: Update apps, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update <app>' installs a new version of that app, if there is one.
#
# You can use '*' in place of <app> to update all apps.
#
# Options:
#   --global, -g  update a globally installed app
#   --force, -f   force update even when there isn't a newer version
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"

$opt, $apps, $err = getopt $args 'gf' 'global','force'
if($err) { "scoop update: $err"; exit 1 }
$global = $opt.g -or $opt.global
$force = $opt.f -or $opt.force

function update_scoop() {
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
	unzip $zipfile $tempdir
	rm $zipfile

	echo 'replacing files...'
	$null = robocopy "$tempdir\scoop-master" $currentdir /mir /njh /njs /nfl /ndl
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
}

function update($app, $global) {
	$old_version = current_version $app $global
	$old_manifest = installed_manifest $app $old_version $global
	$install = install_info $app $old_version $global

	# re-use architecture, bucket and url from first install
	$architecture = $install.architecture
	$bucket = $install.bucket
	$url = $install.url

	# check dependencies
	$deps = @(deps $app $architecture) | ? { !(installed $_) }
	$deps | % { install_app $_ $architecture $global }

	$version = latest_version $app $bucket $url

	if(!$force -and ($old_version -eq $version)) {
		warn "the latest version of $app ($version) is already installed."
		"run 'scoop update' to check for new versions."
		return
	}
	if(!$version) { abort "no manifest available for $app" } # installed from a custom bucket/no longer supported

	$manifest = manifest $app $bucket $url

	"updating $app ($old_version -> $version)"

	$dir = versiondir $app $old_version	$global

	"uninstalling $app ($old_version)"
	run_uninstaller $old_manifest $architecture $dir
	rm_shims $old_manifest $global
	env_rm_path $old_manifest $dir $global
	env_rm $old_manifest $global
	# note: keep the old dir in case it contains user files

	"installing $app ($version)"
	$dir = ensure (versiondir $app $version $global)

	# save info for uninstall
	save_installed_manifest $app $bucket $dir $url
	save_install_info @{ 'architecture' = $architecture; 'url' = $url; 'bucket' = $bucket } $dir

	$fname = dl_urls $app $version $manifest $architecture $dir
	unpack_inno $fname $manifest $dir
	pre_install $manifest
	run_installer $fname $manifest $architecture $dir
	ensure_install_dir_not_in_path $dir
	create_shims $manifest $dir $global
	env_add_path $manifest $dir $global
	env_set $manifest $dir $global
	post_install $manifest

	success "$app was updated from $old_version to $version"

	show_notes $manifest
}

function ensure_all_installed($apps, $global) {
	$app = $apps | ? { !(installed $_ $global) } | select -first 1 # just get the first one that's not installed
	if($app) {
		if(installed $app (!$global)) {
			function wh($g) { if($g) { "globally" } else { "for your account" } }
			write-host "$app isn't installed $(wh $global), but it is installed $(wh (!$global))" -f darkred
			"try updating $(if($global) { 'without' } else { 'with' }) the --global (or -g) flag instead"
			exit 1
		} else {
			abort "$app isn't installed"
		}
	}
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
	return ,@($apps |% { ,@($_, $global) })
}

if(!$apps) {
	if($global) {
		"scoop update: --global is invalid when <app> not specified"; exit 1
	}
	update_scoop
} else {
	if($global -and !(is_admin)) {
		'ERROR: you need admin rights to update global apps'; exit 1
	}

	if($apps -eq '*') {
		$apps = applist (installed_apps $false) $false
		if($global) {
			$apps += applist (installed_apps $true) $true
		}
	} else {
		ensure_all_installed $apps $global
		$apps = applist $apps $global
	}

	# $apps is now a list of ($app, $global) tuples
	$apps | % { update @_ }
}

exit 0