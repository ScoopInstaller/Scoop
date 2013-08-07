# Usage: scoop search [query]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
# 
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\buckets.ps1')
. (relpath '..\lib\manifest.ps1')
. (relpath '..\lib\versions.ps1')

function search_bucket($bucket) {
    $apps = apps_in_bucket (bucketdir $bucket)
    if($query) { $apps = $apps | ? { $_ -like "*$query*" } }
    $apps | % { "  $_ ($(latest_version $_))"}
}

"main bucket:"
search_bucket($null)
""

@(buckets) | % { 
    "'$_' bucket:"
    search_bucket $_
    ""
}

exit 0