. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\opts.ps1"

filter_tests $args

test 'handle short option with required argument missing' {
	$null, $null, $err = getopt '-x' 'x:' ''
	assert $err -eq 'option -x requires an argument'

	$null, $null, $err = getopt '-xy' 'x:y' ''
	assert $err -eq 'option -x requires an argument'
}

test 'handle long option with required argument missing' {
	$null, $null, $err = getopt '--arb' '' 'arb='
	assert $err -eq 'option --arb requires an argument'
}

test 'handle unrecognized short option' {
	$null, $null, $err = getopt '-az' 'a' ''
	assert $err -eq 'option -z not recognized'
}

test 'handle unrecognized long option' {
	$null, $null, $err = getopt '--non-exist' '' ''
	assert $err -ne $null
	assert $err -eq 'option --non-exist not recognized'

	$null, $null, $err = getopt '--global','--another' 'abc:de:' 'global','one'
	assert $err -eq 'option --another not recognized'
}

test 'remaining args returned' {
	$opt, $rem, $err = getopt '-g','rem' 'g' ''
	assert $err -eq $null
	assert $opt.g -eq $true
	assert $rem -ne $null
	assert $rem.length -eq 1
	assert $rem[0] -eq 'rem'
}

test 'get a long flag and a short option with argument' {
	$a = "--global -a 32bit test" -split ' '
	$opt, $rem, $err = getopt $a 'ga:' 'global','arch='
	assert $err -eq $null
	assert $opt.global -eq $true
	assert $opt.a -eq '32bit'
}

test_results
