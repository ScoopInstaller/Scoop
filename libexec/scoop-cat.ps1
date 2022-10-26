# Usage: scoop cat <app>
# Summary: Show content of specified manifest.
# Help: Show content of specified manifest.
# If configured, `bat` will be used to pretty-print the JSON.
# See `cat_style` in `scoop help config` for further information.

param($app)

. "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest'

if (!$app) { error '<app> missing'; my_usage; exit 1 }

$null, $manifest, $bucket, $url = Get-Manifest $app

if ($manifest) {
        $style = get_config CAT_STYLE
        if ($style) {
                $manifest | ConvertToPrettyJson | bat --no-paging --style $style --language json
        } else {
                $manifest | ConvertToPrettyJson
        }
} else {
        abort "Couldn't find manifest for '$app'$(if($url) { " at the URL $url" })."
}

exit $exitCode
