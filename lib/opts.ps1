function parse_args($a) {
	$apps = @(); $arch = $null; $global = $false

	for($i = 0; $i -lt $a.length; $i++) {
		$arg = $a[$i]
		if($arg.startswith('-')) {
			switch($arg) {
				'-arch' {
					if($a.length -gt $i + 1) { $arch = $a[$i++] }
					else { write-host '-arch parameter requires a value'; exit 1 }
				}
				'-global' {
					$global = $true
				}
				default {
					write-host "unrecognised parameter: $arg"; exit 1
				}
			}
		} else {
			$apps += $arg
		}
	}

	$apps, $arch, $global
}

# returns opts (hash), remaining args (array), error (string)
function getopt($argv, $shortopts, $longopts) {
	$opts = @{}; $rem = @()

	function err($msg) {
		$opts, $rem, $msg
	}

	$longopts = @($longopts)
	for($i = 0; $i -lt $argv.length; $i++) {
		$arg = $argv[$i]

		if($arg.startswith('--')) {
			$name = $arg.substring(2)
			if(!($longopts -contains $name)) {
				return err "option --$name not recognized"
			}
		}
	}

	$opts, $rem
}