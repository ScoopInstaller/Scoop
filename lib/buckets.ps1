$bucketsdir = "$scoopdir\buckets"

function bucketdir($name) {
    if(!$name) { return relpath "..\bucket" } # main bucket

    "$bucketsdir\$name"
}

function known_bucket_repos {
    $dir = versiondir 'scoop' 'current'
    $json = "$dir\buckets.json"
    gc $json -raw | convertfrom-json -ea stop
}

function known_bucket_repo($name) {
    $buckets = known_bucket_repos
    $buckets.$name
}

function apps_in_bucket($dir) {
    gci $dir | ? { $_.name.endswith('.json') } | % { $_ -replace '.json$', '' }
}

function buckets([switch]$known) {
    if ($known) {
        known_bucket_repos | Get-Member | ? { $_.MemberType -eq 'NoteProperty' } | Select -Expand Name
    } else {
        $buckets = @()
        if(test-path $bucketsdir) {
            gci $bucketsdir | % { $buckets += $_.name }
        }
        $buckets
    }
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
