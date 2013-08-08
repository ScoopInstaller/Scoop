$bucketsdir = "$scoopdir\buckets"

function bucketdir($name) {
    if(!$name) { return relpath "..\bucket" } # main bucket

    "$bucketsdir\$name"
}

function known_bucket_repo($name) {
    $dir = versiondir 'scoop' 'current'
    $json = "$dir\buckets.json"
    $buckets = gc $json -raw | convertfrom-json -ea stop
    $buckets.$name
}

function apps_in_bucket($dir) {
    gci $dir | ? { $_.name.endswith('.json') } | % { $_ -replace '.json$', '' }
}

function buckets {
    $buckets = @()
    if(test-path $bucketsdir) {
        gci $bucketsdir | % { $buckets += $_.name }
    }
    $buckets
}

function find_manifest($app) {
    @($null) + @(buckets) | % { # null for main bucket
        $manifest = manifest $app $_
        if($manifest) { return $manifest, $_ }
    }
}

<#
# convert an object to a hashtable
function hashtable($obj) {
    $h = @{ }
    $obj.psobject.properties | % {
        $h[$_.name] = hashtable_val($_.value);
    }
    return $h
}
function hashtable_val($obj) {
    if($obj -is [object[]]) {
        return $_.value | % { hashtable_val($_) }
    }
    if($obj.gettype().name -eq 'pscustomobject') { # -is is unreliable
        return hashtable($obj)
    }
    return $obj # assume primitive
}
#>