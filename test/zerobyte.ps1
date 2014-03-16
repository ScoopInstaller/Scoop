. "$psscriptroot\..\lib\core.ps1"

$zerobyte = "$psscriptroot\fixtures\zerobyte.zip"
$small = "$psscriptroot\fixtures\small.zip"

$to = "$psscriptroot\tmp\zerobyte"

function test($from) {
	$to = "$psscriptroot\tmp\$(strip_ext (fname $from))"
	
	# clean-up from previous runs
	if(test-path $to) {
		write-host "removing $to"
		rm -r -force $to
	}

	write-host "unzipping $from to $to"
	unzip_old $from $to	
}


test $zerobyte
test $small