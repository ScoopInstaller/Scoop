# Usage: scoop export > scoopfile.json
# Summary: Exports installed apps, buckets (and optionally configs) in JSON format
# Options:
#   -c, --config       Export the Scoop configuration file too

. "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'

$export = @{}

if ($args[0] -eq '-c' -or $args[0] -eq '--config') {
    $export.config = & "$PSScriptRoot\scoop-config.ps1" 6>$null
    # Remove machine-specific properties
    foreach ($prop in 'lastUpdate', 'rootPath', 'globalPath', 'cachePath') {
        $export.config.PSObject.Properties.Remove($prop)
    }
}

$export.buckets = @(& "$PSScriptRoot\scoop-bucket.ps1" list 6>$null)
$export.apps    = @(& "$PSScriptRoot\scoop-list.ps1"        6>$null)

$export | ConvertToPrettyJSON

exit 0
