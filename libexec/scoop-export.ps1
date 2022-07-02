# Usage: scoop export > scoopfile.json
# Summary: Exports installed apps, buckets (and optionally configs) in JSON format
# Help: Options:
#   -c, --config       Export the Scoop configuration file too

. "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'

$export = @{}

if ($args[0] -eq '-c' -or $args[0] -eq '--config') {
    $export.config = $scoopConfig
    # Remove machine-specific properties
    foreach ($prop in 'lastUpdate', 'rootPath', 'globalPath', 'cachePath', 'alias') {
        $export.config.PSObject.Properties.Remove($prop)
    }
}

$export.buckets = list_buckets
$export.apps = @(& "$PSScriptRoot\scoop-list.ps1" 6>$null)

$export | ConvertToPrettyJSON

exit 0
