if(!$script:run) { $script:run = 0 }
if(!$script:failed) { $script:failed = 0 }

function filter_tests($arg) {
	if(!$arg) { return }
	$script:filter = $arg -join ' '
	write-host "filtering by '$filter'"
}
function test($desc, $assertions) {
	if($filter -and $desc -notlike "*$filter*") { return }
	$script:test = $desc
	$assertions.invoke()
	$script:test = $null
}

function assert($x,$eq='__undefined',$ne='__undefined') {
	$script:run++

	if($args.length -gt 0) {
		fail "unexpected arguments: $args"
	}

	if($eq -ne "__undefined") {
		if($x -ne $eq) { fail "$(fmt $x) != $(fmt $eq)" }
	}

	if($ne -ne "__undefined") {
		if($x -eq $ne) { fail "$(fmt $x) == $(fmt $ne)" }	
	}
}

function test_results {
	"$script:run tests run, $script:failed failed"
}

function script:fail($msg) {
	$script:failed++
	$invoked = (get-variable -scope 1 myinvocation).value

	$script = split-path $invoked.scriptname -leaf
	$line = $invoked.scriptlinenumber

	if($script:test) { $msg = "$script:test`r`n      -> $msg" }

	write-host "FAIL: $msg" -f red
	write-host "$script line $line`:"
	write-host (($invoked.positionmessage -split "`r`n")[1..2] -join "`r`n")
}

function script:fmt($var) {
	if($var -eq $null) { return "`$null" }
	if($var -is [string]) { return "'$var'" }
	return $var
}