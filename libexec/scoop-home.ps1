# Usage: scoop home <app>
# Summary: Opens the app homepage
param($app)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"

reset_aliases

$exitCode = 0

if($app) {
    $manifest, $bucket = find_manifest $app
    if($manifest) {
        if ([string]::isnullorempty($manifest.homepage)) {
            error "Could not find homepage in manifest for '$app'."
            $exitCode = 1
        } else {
            Start-Process $manifest.homepage
        }
    } else {
        error "Could not find manifest for '$app'."
        $exitCode = 1
    }
} else { my_usage }

exit $exitCode
