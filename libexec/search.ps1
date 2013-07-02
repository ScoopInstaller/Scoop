# Usage: scoop search [query]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
# 
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\manifest.ps1')
. (relpath '..\lib\versions.ps1')

$bucket = relpath '..\bucket'
$apps = apps_in_bucket $bucket

if($query) { $apps = $apps | ? { $_ -like "*$query*" } }

$apps | % { "$_ ($(latest_version $_))"}

""

exit 0