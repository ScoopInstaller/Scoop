if(!$script:run) { $script:run = 0 }
if(!$script:failed) { $script:failed = 0 }

function fail($msg) {
	$script:failed++
	$invoked = (get-variable -scope 1 myinvocation).value

	$script = split-path $invoked.scriptname -leaf
	$line = $invoked.scriptlinenumber
	write-host "FAIL: $msg" -f red
	write-host $invoked.positionmessage
}

function fmt($var) {
	if($var -is [string]) { return "'$var'" }
	return $var
}

function assert(
	$x,$eq='__undefined',$ne='__undefined') {
	$script:run++

	if($args.length -gt 0) {
		fail "unexpected arguments: $args"
	}

	if($eq -ne "__undefined") {
		if($x -ne $eq) { fail "$(fmt($x)) != $(fmt($eq))" }
	}

	if($ne -ne "__undefined") {
		if($x -eq $ne) { fail "$(fmt($x)) == $(fmt($ne))" }	
	}
}

function test_results {
	"$script:run tests run, $script:failed failed"
}