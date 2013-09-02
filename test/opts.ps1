. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\opts.ps1"

$a = "--global -a 32bit test" -split ' '

$opt, $rem, $err = getopt $a "ga" "global", "arch"

assert_eq $opt.global $true
assert_eq $opt.a "32bit"

$null, $null, $err = getopt "--non-exist", "", ""
assert_neq $err $null
assert_eq $err "option --non-exist not recognized"
