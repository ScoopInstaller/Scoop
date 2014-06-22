. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\versions.ps1"

test 'compare version with integer-string mismatch' {
	$a = '1.8.9'
	$b = '1.8.5-1'
	$res = compare_versions $a $b
	assert $res -eq 1
}

test_results