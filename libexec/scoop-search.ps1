# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)

. "$PSScriptRoot\..\lib\manifest.ps1" # 'manifest'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-LatestVersion'

$list = @()

try {
    $query = New-Object Regex $query, 'IgnoreCase'
} catch {
    abort "Invalid regular expression: $($_.Exception.InnerException.Message)"
}

$githubtoken = Get-GitHubToken
$authheader = @{}
if ($githubtoken) {
    $authheader = @{'Authorization' = "token $githubtoken"}
}

function bin_match($manifest, $query) {
    if (!$manifest.bin) { return $false }
    $bins = foreach ($bin in $manifest.bin) {
        $exe, $alias, $args = $bin
        $fname = Split-Path $exe -Leaf -ErrorAction Stop

        if ((strip_ext $fname) -match $query) { $fname }
        elseif ($alias -match $query) { $alias }
    }
    if ($bins) { return $bins }
    else { return $false }
}

function search_bucket($bucket, $query) {
    $apps = apps_in_bucket (Find-BucketDirectory $bucket) | ForEach-Object { @{ name = $_ } }

    if ($query) {
        $apps = $apps | Where-Object {
            if ($_.name -match $query) { return $true }
            $bin = bin_match (manifest $_.name $bucket) $query
            if ($bin) {
                $_.bin = $bin
                return $true
            }
        }
    }
    $apps | ForEach-Object { $_.version = (Get-LatestVersion -AppName $_.name -Bucket $bucket); $_ }
}

function download_json($url) {
    $ProgressPreference = 'SilentlyContinue'
    $result = Invoke-WebRequest $url -UseBasicParsing -Headers $authheader | Select-Object -ExpandProperty content | ConvertFrom-Json
    $ProgressPreference = 'Continue'
    $result
}

function github_ratelimit_reached {
    $api_link = 'https://api.github.com/rate_limit'
    $ret = (download_json $api_link).rate.remaining -eq 0
    if ($ret) {
        Write-Host "GitHub API rate limit reached.
Please try again later or configure your API token using 'scoop config gh_token <your token>'."
    }
    $ret
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
    $names = $buckets | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty name

    $results = $names | Where-Object { !(Test-Path $(Find-BucketDirectory $_)) } | ForEach-Object {
        @{ "bucket" = $_; "results" = (search_remote $_ $query) }
    } | Where-Object { $_.results }

    if ($results.count -gt 0) {
        Write-Host "Results from other known buckets...
(add them using 'scoop bucket add <bucket name>')"
    }

    $results | ForEach-Object {
        $name = $_.bucket
        $_.results | ForEach-Object {
            $item = [ordered]@{}
            $item.Name = $_
            $item.Source = $name
            $list += [PSCustomObject]$item
        }
    }

    $list
}

Get-LocalBucket | ForEach-Object {
    $res = search_bucket $_ $query
    $local_results = $local_results -or $res
    if ($res) {
        $name = "$_"

        $res | ForEach-Object {
            $item = [ordered]@{}
            $item.Name = $_.name
            $item.Version = $_.version
            $item.Source = $name
            $item.Binaries = ""
            if ($_.bin) { $item.Binaries = $_.bin -join ' | ' }
            $list += [PSCustomObject]$item
        }
    }
}

if ($list.Length -gt 0) {
    Write-Host "Results from local buckets..."
    $list
}

if (!$local_results -and !(github_ratelimit_reached)) {
    $remote_results = search_remotes $query
    if (!$remote_results) {
        warn "No matches found."
        exit 1
    }
    $remote_results
}

exit 0
