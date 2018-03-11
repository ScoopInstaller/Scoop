# Usage: scoop prefix <app>
# Summary: Returns the path to the specified app
param($app)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"

reset_aliases

if($app) {
    $app_path = appdir $app
    if($app_path) {
        info("$app_path")
    }
    else {
        abort "Could not find app path for '$app'."
    }
} else { my_usage }

exit 0
