$bucketsdir = "$scoopdir\buckets"

function bucketdir($name) {
    if(!$name) { return relpath "..\bucket" } # main bucket

    "$bucketsdir\$name"
}

function known_bucket_repos {
    $dir = versiondir 'scoop' 'current'
    $json = "$dir\buckets.json"
    Get-Content $json -raw | convertfrom-json -ea stop
}

function known_bucket_repo($name) {
    $buckets = known_bucket_repos
    $buckets.$name
}

function apps_in_bucket($dir) {
    Get-ChildItem $dir | Where-Object { $_.name.endswith('.json') } | ForEach-Object { $_ -replace '.json$', '' }
}

function buckets {
    $buckets = @()
    if(test-path $bucketsdir) {
        Get-ChildItem $bucketsdir | ForEach-Object { $buckets += $_.name }
    }
    $buckets
}

function find_manifest($app, $bucket) {
    if ($bucket) {
        $manifest = manifest $app $bucket
        if ($manifest) { return $manifest, $bucket }
        return $null
    }

    $buckets = @($null) + @(buckets) # null for main bucket
    foreach($bucket in $buckets) {
        $manifest = manifest $app $bucket
        if($manifest) { return $manifest, $bucket }
    }
}

function new_issue_msg($app, $bucket, $title, $body) {
    $app, $manifest, $bucket, $url = locate $app $bucket
    $url = known_bucket_repo $bucket
    if($manifest -and $null -eq $url -and $null -eq $bucket) {
        $url = 'https://github.com/lukesampson/scoop'
    }
    if(!$url) {
        return "Please contact the bucket maintainer!"
    }

    $title = [System.Web.HttpUtility]::UrlEncode("$app@$($manifest.version): $title")
    $body = [System.Web.HttpUtility]::UrlEncode($body)
    $url = $url -replace '^(.*).git$','$1'
    $url = "$url/issues/new?title=$title"
    if($body) {
        $url += "&body=$body"
    }

    $msg = "`nPlease try again or create a new issue by using the following link and paste your console output:"
    return "$msg`n$url"
}
