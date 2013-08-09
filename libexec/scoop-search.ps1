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
    if($query) { $apps = $apps | ? { $_ -match $query } }
    $apps | % { "  $_ ($(latest_version $_ $bucket))"}
}

@($null) + @(buckets) | % { # $null is main bucket
    $res = search_bucket($_)
    if($res) {
        $name = "$_"
        if(!$_) { $name = "main" }
        
        "$name bucket:"
        $res
        ""
    }
}

exit 0