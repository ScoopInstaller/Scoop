. "$psscriptroot\tests.ps1"
. "$psscriptroot\..\lib\install.ps1"

$working_dir = setup_working

# copy packages from 1.0 to 1.1
$from = "$working_dir\1.0"
$to = "$working_dir\1.1"

travel_dir $from $to

test 'common directory remains unchanged in destination' {
	assert (gc "$to\common\version.txt") -eq "version 1.1" 
	assert (gc "$to\common with spaces\version.txt") -eq "version 1.1" 
}

test 'common directory remains unchanged in source' {
	assert (test-path "$from\common")
	assert (test-path "$from\common with spaces")
	assert (gc "$from\common\version.txt") -eq "version 1.0"
	assert (gc "$from\common with spaces\version.txt") -eq "version 1.0"
}

test 'old package present in new' {
	assert (test-path "$to\package_a") 
}

test 'old package doesn''t remain in old' {
	assert (!(test-path "$from\package_a"))
}

test 'old subdir in common dir not copied' {
	assert (!(test-path "$to\common\subdir"))
}

test 'common file remains unchanged in destination' {
	assert (gc "$to\common_file.txt") -eq "version 1.1"
}

test_results