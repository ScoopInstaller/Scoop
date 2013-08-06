function config_path { "$scoopdir\config.json" }

function hashtable_val($obj) {
    if($obj -is [object[]]) {
        return $_.value | % {
            hashtable_val($_)
        }
    }
    if($obj.gettype().name -eq 'pscustomobject') { # -is is unreliable
        return hashtable($obj)
    }
    return $obj # assume primitive
}

function hashtable($obj) {
    $h = @{ }
    $obj.psobject.properties | % {
        $h[$_.name] = hashtable_val($_.value);
    }
    return $h
}

function config {
    $path = config_path
    if(!(test-path $path)) { return @{ } } 

    $json = gc $path -raw | convertfrom-json -ea stop
    hashtable($json)
}

function save_config($config) {
    $path = config_path
    $config | convertto-json -depth 10 > $path
}