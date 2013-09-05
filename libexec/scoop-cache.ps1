# Usage: scoop cache show|rm [app]
# Summary: Show or clear the download cache
# Help: Scoop caches downloads so you don't need to download the same files
# when you uninstall and re-install the same version of an app.
#
# You can use
#     scoop cache show
# to see what's in the cache, and
#     scoop cache rm <app> to remove downloads for a specific app.
param($cmd, $app)

. "$psscriptroot\..\lib\help.ps1"

switch($cmd) {
	'rm' {
		if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }
		rm "$scoopdir\cache\$app#*"
	}
	'show' {
		gci "$scoopdir\cache" | select name 
	}
	default {
		"cache '$cmd' not supported"; my_usage; exit 1
	}
}

exit 0