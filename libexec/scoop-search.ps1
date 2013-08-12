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

function bin_match($manifest, $query) {
    if(!$manifest.bin) { return $false }
    @($manifest.bin) | % {
        $fname = strip_ext (split-path $_ -leaf)
        if($fname -match $query) { return $true }
    }
    $false
}

function search_bucket($bucket, $query) {
    $apps = apps_in_bucket (bucketdir $bucket)
    if($query) { $apps = $apps | ? {
        ($_ -match $query) -or (bin_match (manifest $_) $query)

    } }
    $apps | % { "  $_ ($(latest_version $_ $bucket))"}
}

@($null) + @(buckets) | % { # $null is main bucket
    $res = search_bucket $_ $query
    if($res) {
        $name = "$_"
        if(!$_) { $name = "main" }
        
        "$name bucket:"
        $res
        ""
    }
}

exit 0