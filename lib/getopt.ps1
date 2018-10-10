# adapted from http://hg.python.org/cpython/file/2.7/Lib/getopt.py
# argv:
#    array of arguments
# shortopts:
#    string of single-letter options. options that take a parameter
#    should be follow by ':'
# longopts:
#    array of strings that are long-form options. options that take
#    a parameter should end with '='
# returns @(opts hash, remaining_args array, error string)
function getopt($argv, $shortopts, $longopts) {
    $opts = @{}; $rem = @()

    function err($msg) {
        $opts, $rem, $msg
    }

    function regex_escape($str) {
        return [regex]::escape($str)
    }

    # ensure these are arrays
    $argv = @($argv)
    $longopts = @($longopts)

    for($i = 0; $i -lt $argv.length; $i++) {
        $arg = $argv[$i]
        if($null -eq $arg) { continue }
        # don't try to parse array arguments
        if($arg -is [array]) { $rem += ,$arg; continue }
        if($arg -is [int]) { $rem += $arg; continue }
        if($arg -is [decimal]) { $rem += $arg; continue }

        if($arg.startswith('--')) {
            $name = $arg.substring(2)

            $longopt = $longopts | Where-Object { $_ -match "^$name=?$" }

            if($longopt) {
                if($longopt.endswith('=')) { # requires arg
                    if($i -eq $argv.length - 1) {
                        return err "Option --$name requires an argument."
                    }
                    $opts.$name = $argv[++$i]
                } else {
                    $opts.$name = $true
                }
            } else {
                return err "Option --$name not recognized."
            }
        } elseif($arg.startswith('-') -and $arg -ne '-') {
            for($j = 1; $j -lt $arg.length; $j++) {
                $letter = $arg[$j].tostring()

                if($shortopts -match "$(regex_escape $letter)`:?") {
                    $shortopt = $matches[0]
                    if($shortopt[1] -eq ':') {
                        if($j -ne $arg.length -1 -or $i -eq $argv.length - 1) {
                            return err "Option -$letter requires an argument."
                        }
                        $opts.$letter = $argv[++$i]
                    } else {
                        $opts.$letter = $true
                    }
                } else {
                    return err "Option -$letter not recognized."
                }
            }
        } else {
            $rem += $arg
        }
    }

    $opts, $rem
}
