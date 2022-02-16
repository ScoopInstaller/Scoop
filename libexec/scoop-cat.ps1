# Usage: scoop cat <app>
# Summary: Show content of specified manifest. If available, `bat` will be used to pretty-print the JSON.

param($app)

. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

reset_aliases

if (!$app) { error '<app> missing'; my_usage; exit 1 }

$app, $bucket, $null = parse_app $app
$app, $manifest, $bucket, $url = Find-Manifest $app $bucket

if ($manifest) {
        if (Get-Command bat -CommandType Application -ErrorAction Ignore) {
                $manifest | ConvertToPrettyJson | bat --no-paging --language json
        } else {
                $manifest | ConvertToPrettyJson
        }
} else {
        abort "Couldn't find manifest for '$app'$(if($url) { " at the URL $url" })."
}

exit $exitCode
