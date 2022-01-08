# Usage: scoop cat <app>
# Summary: Show content of specified manifest.

param($app)

. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

if (!$app) { error '<app> missing'; my_usage; exit 1 }

$app, $bucket, $null = parse_app $app
$app, $manifest, $bucket, $url = Find-Manifest $app $bucket

if ($manifest) {
        $manifest | ConvertToPrettyJson | Write-Host
} else {
        abort "Couldn't find manifest for '$app'$(if($url) { " at the URL $url" })."
}

exit $exitCode
