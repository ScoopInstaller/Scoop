# Usage: scoop versions <app>
# Summary: List available versions for <app>
# Help: 'scoop versions' lists all the available versions of the given app within scoop

param($app)

. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"

function script:reverse {
    $arr = @($input)
    [array]::reverse($arr)
    $arr
}

$history = app_history $app
$versions = $history | select -expandproperty version
if ($versions) {
    "versions of $app available:"
    sort_versions $versions | reverse |% { "  $_" }
}
