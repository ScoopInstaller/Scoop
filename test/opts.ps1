. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\opts.ps1"

$a = "--global -a 32bit test" -split ' '

$opt, $rem, $err = getopt $a "ga:" "global", "arch="

assert $err -eq $null
assert $opt.global -eq $true
assert $opt.a -eq "32bit"

$null, $null, $err = getopt "--non-exist", "", ""
assert $err -ne $null
assert $err -eq "option --non-exist not recognized"

test_results
