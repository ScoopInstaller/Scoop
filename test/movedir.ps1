. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\core.ps1"

$working_dir = setup_working

$extract_dir = "subdir"
$extract_to = $null

$dir = "$working_dir\user with space"

# assumes the current directory has no spaces!
test 'move with no spaces in path' {
	$dir = "$working_dir\user"
	movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

	assert (gc "$dir\test.txt") -eq "this is the one" 
	assert (!(test-path "$dir\_scoop_extract\$extract_dir"))
}

test 'move with spaces in path' {
	$dir = "$working_dir\user with space"
	movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

	assert (gc "$dir\test.txt") -eq "this is the one" 
	assert (!(test-path "$dir\_scoop_extract\$extract_dir"))

	# test trailing \ in from dir
	movedir "$dir\_scoop_extract\$null" "$dir\another"
	assert (gc "$dir\another\test.txt") -eq "testing"
	assert (!(test-path "$dir\_scoop_extract"))
}

test_results