. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\opts.ps1"

$a = "--global -a 32bit test" -split ' '

$opt, $rem, $err = getopt $a "ga:" "global", "arch="

is_equal $err, $null
is_equal $opt.global $true
is_equal $opt.a "32bit"

$null, $null, $err = getopt "--non-exist", "", ""
is_not_equal $err $null
is_equal $err "option --non-exist not recognized"
