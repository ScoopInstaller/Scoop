# Usage: scoop search [query]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
# 
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve '..\manifest.ps1')
. (resolve '..\versions.ps1')

$bucket = resolve '..\..\bucket'
$apps = apps_in_bucket $bucket

if($query) { $apps = $apps | ? { $_ -like "*$query*" } }

$apps | % { "$_ ($(latest_version $_))"}

""

exit 0