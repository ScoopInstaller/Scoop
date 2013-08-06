function config_path { return "$scoopdir\config.json" }

function hashtable_val($obj) {
    if($obj -is [object[]]) {
        return $_.value | % {
            hashtable_val($_.psobject.baseobject)
        }
    }
    if($obj -is [pscustomobject]) {
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
    if(!(test-path $path)) { "{ }" > $path } 

    $json = convertfrom-json $path -ea stop

}

function config_add_list($name, $value) {
    $config = config
    if($config.$name) {

    }
}