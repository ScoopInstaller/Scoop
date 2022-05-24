# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)

. "$PSScriptRoot\..\lib\manifest.ps1" # 'manifest'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-LatestVersion'

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
    $apps = apps_in_bucket (Find-BucketDirectory $bucket) | ForEach-Object {
        @{ name = $_ }
    }

    if($query) {
        try {
            $query = new-object regex $query, 'IgnoreCase'
        } catch {
            abort "Invalid regular expression: $($_.exception.innerexception.message)"
        }

        $apps = $apps | Where-Object {
            if($_.name -match $query) { return $true }
            $bin = bin_match (manifest $_.name $bucket) $query
            if($bin) {
                $_.bin = $bin; return $true;
            }
        }
    }
    $apps | ForEach-Object { $_.version = (Get-LatestVersion -AppName $_.name -Bucket $bucket); $_ }
}

function download_json($url) {
    $ProgressPreference = 'SilentlyContinue'
    $result = Invoke-WebRequest $url -UseBasicParsing | Select-Object -ExpandProperty content | ConvertFrom-Json
    $ProgressPreference = 'Continue'
    $result
}

function github_ratelimit_reached {
    $api_link = 'https://api.github.com/rate_limit'
    (download_json $api_link).rate.remaining -eq 0
}

function search_remote($bucket, $query) {
    $uri = [System.Uri](known_bucket_repo $bucket)
    if ($uri.AbsolutePath -match '/([a-zA-Z0-9]*)/([a-zA-Z0-9-]*)(?:.git|/)?') {
        $user = $Matches[1]
        $repo_name = $Matches[2]
        $api_link = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        $result = download_json $api_link | Select-Object -ExpandProperty tree |
            Where-Object -Value "^bucket/(.*$query.*)\.json$" -Property Path -Match |
            ForEach-Object { $Matches[1] }
    }

    $result
}

function search_remotes($query) {
    $buckets = known_bucket_repos
    $names = $buckets | get-member -m noteproperty | Select-Object -exp name

    $results = $names | Where-Object { !(test-path $(Find-BucketDirectory $_)) } | ForEach-Object {
        @{"bucket" = $_; "results" = (search_remote $_ $query)}
    } | Where-Object { $_.results }

    if ($results.count -gt 0) {
        "Results from other known buckets..."
        "(add them using 'scoop bucket add <name>')"
        ""
    }

    $results | ForEach-Object {
        "'$($_.bucket)' bucket (install using 'scoop install $($_.bucket)/<app>'):"
        $_.results | ForEach-Object { "    $_" }
        ""
    }
}

Get-LocalBucket | ForEach-Object {
    $res = search_bucket $_ $query
    $local_results = $local_results -or $res
    if($res) {
        $name = "$_"

        Write-Host "'$name' bucket:"
        $res | ForEach-Object {
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
