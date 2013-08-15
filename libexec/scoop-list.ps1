# Usage: scoop list [query]
# Summary: List installed apps
# Help: Lists all installed apps, or the apps matching the supplied query.
param($query)

. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\versions.ps1')
. (relpath '..\lib\manifest.ps1')
. (relpath '..\lib\buckets.ps1')

$apps = installed_apps

if($apps) {
	echo "Installed apps$(if($query) { `" matching '$query'`"}):
"
	$apps | ? { !$query -or ($_ -match $query) } | % {
		"  $_ ($(current_version $_))"
	}
	""
} else { "there aren't any apps installed" }

exit 0
