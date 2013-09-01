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