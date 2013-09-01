# Usage: scoop list [query]
# Summary: List installed apps
# Help: Lists all installed apps, or the apps matching the supplied query.
param($query)

. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\versions.ps1')
. (relpath '..\lib\manifest.ps1')
. (relpath '..\lib\buckets.ps1')

$local = installed_apps $false | % { @{ name = $_ } }
$global = installed_apps $true | % { @{ name = $_; global = $true } }

$apps = $local + $global

if($apps) {
	echo "Installed apps$(if($query) { `" matching '$query'`"}):
"
	$apps | sort name | ? { !$query -or ($_.name -match $query) } | % {
        $app = $_.name
        $global = $_.global
		"  $app ($(current_version $app $global))$(if($global) { ' *global*'})"
	}
	""
} else { "there aren't any apps installed" }

exit 0
