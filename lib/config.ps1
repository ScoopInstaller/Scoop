$cfgpath = "~/.scoop"

function hashtable($obj) {
    $h = @{ }
    $obj.psobject.properties | ForEach-Object {
        $h[$_.name] = hashtable_val $_.value
    }
    return $h
}

function hashtable_val($obj) {
    if($null -eq $obj) { return $null }
    if($obj -is [array]) {
        $arr = @()
        $obj | ForEach-Object {
            $val = hashtable_val $_
            if($val -is [array]) {
                $arr += ,@($val)
            } else {
                $arr += $val
            }
        }
        return ,$arr
    }
    if($obj.gettype().name -eq 'pscustomobject') { # -is is unreliable
        return hashtable $obj
    }
    if($obj -eq [bool]::TrueString -or $obj -eq [bool]::FalseString) {
        $obj = [System.Convert]::ToBoolean($obj)
    }
    return $obj # assume primitive
}

function load_cfg {
    if(!(test-path $cfgpath)) { return $null }

    try {
        hashtable (Get-Content $cfgpath -raw | convertfrom-json -ea stop)
    } catch {
        write-host "ERROR loading $cfgpath`: $($_.exception.message)"
    }
}

function get_config($name) {
    return $cfg.$name
}

function set_config($name, $val) {
    if(!$cfg) {
        $cfg = @{ $name = $val }
    } else {
        if($val -eq [bool]::TrueString -or $val -eq [bool]::FalseString) {
            $val = [System.Convert]::ToBoolean($val)
        }
        $cfg.$name = $val
    }

    if($null -eq $val) {
        $cfg.remove($name)
    }

    convertto-json $cfg | set-content $cfgpath -encoding utf8
}

$cfg = load_cfg

# setup proxy
# note: '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
$p = get_config 'proxy'
if($p) {
    try {
        $cred, $address = $p -split '(?<!\\)@'
        if(!$address) {
            $address, $cred = $cred, $null # no credentials supplied
        }

        if($address -eq 'none') {
            [net.webrequest]::defaultwebproxy = $null
        } elseif($address -ne 'default') {
            [net.webrequest]::defaultwebproxy = new-object net.webproxy "http://$address"
        }

        if($cred -eq 'currentuser') {
            [net.webrequest]::defaultwebproxy.credentials = [net.credentialcache]::defaultcredentials
        } elseif($cred) {
            $user, $pass = $cred -split '(?<!\\):' | ForEach-Object { $_ -replace '\\([@:])','$1' }
            [net.webrequest]::defaultwebproxy.credentials = new-object net.networkcredential($user, $pass)
        }
    } catch {
        warn "Failed to use proxy '$p': $($_.exception.message)"
    }
}
