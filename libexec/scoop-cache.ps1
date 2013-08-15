# Usage: scoop cache show|rm [app]
# Summary: Show or clear the download cache
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