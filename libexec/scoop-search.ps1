# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"

reset_aliases

function bin_match($manifest, $query) {
    if(!$manifest.bin) { return $false }
    foreach($bin in $manifest.bin) {
        $exe, $alias, $args = $bin
        $fname = split-path $exe -leaf -ea stop

        if((strip_ext $fname) -match $query) { return $fname }
        if($alias -match $query) { return $alias }
    }
    $false
}

function search_bucket($bucket, $query) {
    $apps = apps_in_bucket (bucketdir $bucket) | % {
        @{ name = $_ }
    }

    if($query) {
        try {
            $query = new-object regex $query, 'IgnoreCase'
        } catch {
            abort "Invalid regular expression: $($_.exception.innerexception.message)"
        }

        $apps = $apps | ? {
            if($_.name -match $query) { return $true }
            $bin = bin_match (manifest $_.name $bucket) $query
            if($bin) {
                $_.bin = $bin; return $true;
            }
        }
    }
    $apps | % { $_.version = (latest_version $_.name $bucket); $_ }
}

function download_json($url) {
    $progressPreference = 'silentlycontinue'
    $result = invoke-webrequest $url -UseBasicParsing | select -exp content | convertfrom-json
    $progressPreference = 'continue'
    $result
}

function github_ratelimit_reached {
    $api_link = "https://api.github.com/rate_limit"
    (download_json $api_link).rate.remaining -eq 0
}

function search_remote($bucket, $query) {
    $repo = known_bucket_repo $bucket

    $uri = [system.uri]($repo)
    if ($uri.absolutepath -match '/([a-zA-Z0-9]*)/([a-zA-Z0-9-]*)(.git|/)?') {
        $user = $matches[1]
        $repo_name = $matches[2]
        $api_link = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        $result = download_json $api_link | select -exp tree |? {
            $_.path -match "(^(.*$query.*).json$)"
        } |% { $matches[2] }
    }

    $result
}

function search_remotes($query) {
    $buckets = known_bucket_repos
    $names = $buckets | get-member -m noteproperty | select -exp name

    $results = $names |? { !(test-path $(bucketdir $_)) } |% {
        @{"bucket" = $_; "results" = (search_remote $_ $query)}
    } |? { $_.results }

    if ($results.count -gt 0) {
        "Results from other known buckets..."
        "(add them using 'scoop bucket add <name>')"
        ""
    }

    $results |% {
        "'$($_.bucket)' bucket:"
        $_.results |% { "    $_" }
        ""
    }
}

@($null) + @(buckets) | % { # $null is main bucket
    $res = search_bucket $_ $query
    $local_results = $local_results -or $res
    if($res) {
        $name = "$_"
        if(!$_) { $name = "main" }

        "'$name' bucket:"
        $res | % {
            $item = "    $($_.name) ($($_.version))"
            if($_.bin) { $item += " --> includes '$($_.bin)'" }
            $item
        }
        ""
    }
}

if (!$local_results -and !(github_ratelimit_reached)) {
    $remote_results = search_remotes $query
    if(!$remote_results) { [console]::error.writeline("No matches found."); exit 1 }
    $remote_results
}

exit 0
