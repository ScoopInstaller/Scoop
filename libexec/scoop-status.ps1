# Usage: scoop status
# Summary: Show status and check for new app versions

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"

function timeago($when) {
	$diff = [datetime]::now - $last_update

	if($diff.totaldays -gt 2) { return "$([int]$diff.totaldays) days ago" }
	if($diff.totalhours -gt 2) { return "$([int]$diff.totalhours) hours ago" }
	if($diff.totalminutes -gt 2) { return "$([int]$diff.totalminutes) minutes ago" }
	return "$([int]$diff.totalseconds) seconds ago"
}

# check when scoop was last updated
$timestamp = "$(versiondir 'scoop' 'current')\last_updated"
if(test-path $timestamp) {
	$last_update = [io.file]::getlastwritetime((resolve-path $timestamp))
	"scoop was last updated $(timeago($last_update))"
}

$failed = @()
$old = @()
$removed = @()
$missing_deps = @()

$true, $false | % { # local and global apps
	$global = $_
	$dir = appsdir $global
	if(!(test-path $dir)) { return }

	gci $dir | ? name -ne 'scoop' | % {
		$app = $_.name
		$version = current_version $app $global
		if($version) {
			$install_info = install_info $app $version $global
		}
		
		if(!$install_info) {
			$failed += @{ $app = $version }; return 
		}

		$manifest = manifest $app $install_info.bucket $install_info.url    
		if(!$manifest) { $removed += @{ $app = $version }; return }

		if((compare_versions $manifest.version $version) -gt 0) {
			$old += @{ $app = @($version, $manifest.version) }
		}

		$deps = @(runtime_deps $manifest) | ? { !(installed $_) }
		if($deps) {
			$missing_deps += ,(@($app) + @($deps))
		}
	}
}



if($old) {
	"updates are available for:"
	$old.keys | % { 
		$versions = $old.$_
		"    $_`: $($versions[0]) -> $($versions[1])"
	}
}

if($removed) {
	"these app manifests have been removed:"
	$removed.keys | % {
		"    $_"
	}
}

if($failed) {
	"these apps failed to install:"
	$failed.keys | % {
		"    $_"
	}
}

if($missing_deps) {
	"missing runtime dependencies:"
	$missing_deps | % {
		$app, $deps = $_
		"    $app requires $([string]::join(',', $deps))"
	}
}

if(!$old -and !$removed -and !$failed -and !$missing_deps) {
	success "everything is ok!"
}

exit 0