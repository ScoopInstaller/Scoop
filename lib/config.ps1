$cfgpath = "~/.scoop"

function hashtable($obj) {
	$h = @{ }
	$obj.psobject.properties | % {
		$h[$_.name] = hashtable_val $_.value		
	}
	return $h
}

function hashtable_val($obj) {
	if($obj -eq $null) { return $null }
	if($obj -is [array]) {
		$arr = @()
		$obj | % {
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
	return $obj # assume primitive
}

function load_cfg {
	if(!(test-path $cfgpath)) { return $null }
	
	try {
		hashtable (gc $cfgpath -raw | convertfrom-json -ea stop)
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
		$cfg.$name = $val
	}

	if($val -eq $null) {
		$cfg.remove($name)
	}

	convertto-json $cfg | out-file $cfgpath -encoding utf8
}

$cfg = load_cfg