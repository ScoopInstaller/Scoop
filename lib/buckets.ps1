$bucketsdir = "$scoopdir\buckets"

<#
.DESCRIPTION
    Return full path for bucket with given name.
    Main bucket will be returned as default.
.PARAMETER name
    Name of bucket
#>
function bucketdir($name) {
    $bucket = relpath '..\bucket' # main bucket

    if ($name) {
        $bucket = "$bucketsdir\$name"
    }
    if (Test-Path "$bucket\bucket") {
        $bucket = "$bucket\bucket"
    }

    return $bucket
}

function known_bucket_repos {
    $dir = versiondir 'scoop' 'current'
    $buckets = "$dir\buckets.json"

    return Scoop-ParseManifest $buckets
}

function known_bucket_repo($name) {
    $buckets = known_bucket_repos
    $buckets.$name
}

function apps_in_bucket($dir) {
    Write-Host $dir -f yellow
    # Use a little bit hacky way, when it't not possible to filter more file extensions
    # https://stackoverflow.com/questions/18616581/how-to-properly-filter-multiple-strings-in-a-powershell-copy-script#18626464
    $manifests = Get-ChildItem "$dir\*" -File -Include '*.json', '*.yaml', '*.yml'

    return $manifests | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
}

function buckets {
    $buckets = @()
    if(Test-Path $bucketsdir) {
        Get-ChildItem $bucketsdir | ForEach-Object { $buckets += $_.Name }
    }
    return $buckets
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
