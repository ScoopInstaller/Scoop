# Usage: scoop home <app>
# Summary: Opens the app homepage
param($app)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"

if($app) {
    $manifest, $bucket = find_manifest $app
    if($manifest) {
        if([string]::isnullorempty($manifest.homepage)) {
            abort "could not find homepage in manifest for '$app'"
        }
        start $manifest.homepage
    }
    else {
        abort "could not find manifest for '$app'"
    }
} else { my_usage }

exit 0