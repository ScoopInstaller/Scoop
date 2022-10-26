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
# NOTES:
#    The first "--" in $argv, if any, will terminate all options; any
# following arguments are treated as non-option arguments, even if
# they begin with a hyphen. The "--" itself will not be included in
# the returned $opts. (POSIX-compatible)
function getopt($argv, $shortopts, $longopts) {
    $opts = @{}; $rem = @()

    function err($msg) {
        $opts, $rem, $msg
    }

    function regex_escape($str) {
        return [Regex]::Escape($str)
    }

    # ensure these are arrays
    $argv = @($argv -split ' ')
    $longopts = @($longopts)

    for ($i = 0; $i -lt $argv.Length; $i++) {
        $arg = $argv[$i]
        if ($null -eq $arg) { continue }
        # don't try to parse array arguments
        if ($arg -is [Array]) { $rem += , $arg; continue }
        if ($arg -is [Int]) { $rem += $arg; continue }
        if ($arg -is [Decimal]) { $rem += $arg; continue }

        if ($arg -eq '--') {
            if ($i -lt $argv.Length - 1) {
                $rem += $argv[($i + 1)..($argv.Length - 1)]
            }
            break
        } elseif ($arg.StartsWith('--')) {
            $name = $arg.Substring(2)

            $longopt = $longopts | Where-Object { $_ -match "^$name=?$" }

            if ($longopt) {
                if ($longopt.EndsWith('=')) {
                    # requires arg
                    if ($i -eq $argv.Length - 1) {
                        return err "Option --$name requires an argument."
                    }
                    $opts.$name = $argv[++$i]
                } else {
                    $opts.$name = $true
                }
            } else {
                return err "Option --$name not recognized."
            }
        } elseif ($arg.StartsWith('-') -and $arg -ne '-') {
            for ($j = 1; $j -lt $arg.Length; $j++) {
                $letter = $arg[$j].ToString()

                if ($shortopts -match "$(regex_escape $letter)`:?") {
                    $shortopt = $Matches[0]
                    if ($shortopt[1] -eq ':') {
                        if ($j -ne $arg.Length - 1 -or $i -eq $argv.Length - 1) {
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
