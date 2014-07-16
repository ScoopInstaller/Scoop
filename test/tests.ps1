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
	$script:run++
	try {
		$assertions.invoke()
	} catch {
		script:fail $_.exception.innerexception.message
	}
	$script:test = $null
}

function assert($x,$eq='__undefined',$ne='__undefined') {
	if($args.length -gt 0) {
		fail "unexpected arguments: $args"
	}

	if($eq -ne "__undefined") {
		if($x -ne $eq) { fail "$(fmt $x) != $(fmt $eq)" }
	} elseif ($ne -ne "__undefined") {
		if($x -eq $ne) { fail "$(fmt $x) == $(fmt $ne)" }	
	} else {
		if(!$x) { fail "$x" }
	}
}

function test_results {
	$col = 'darkgreen'
	$res = 'all passed'
	if($script:failed -gt 0) {
		$col = 'darkred'
		$res = "$script:failed failed"
	}

	write-host "ran $script:run tests, " -nonewline
	write-host $res -f $col
}

function script:fail($msg) {
	$script:failed++
	$invoked = (get-variable -scope 1 myinvocation).value

	$script = split-path $invoked.scriptname -leaf
	$line = $invoked.scriptlinenumber

	if($script:test) { $msg = "$script:test`r`n      -> $msg" }

	write-host "FAIL: $msg" -f darkred
	write-host "$script line $line`:"
	write-host (($invoked.positionmessage -split "`r`n")[1..2] -join "`r`n")
}

function script:fmt($var) {
	if($var -eq $null) { return "`$null" }
	if($var -is [string]) { return "'$var'" }
	return $var
}

# copies fixtures to a working directory
function setup_working {
	# get the name of the test from the file that called this function
	$file = (get-variable -scope 1 myinvocation).value.mycommand.name
	$name = [io.path]::getfilenamewithoutextension($file)

	$fixtures = "$psscriptroot\fixtures\$name"
	if(!(test-path $fixtures)) {
		write-host "couldn't find fixtures for $name at $fixtures" -f red
		exit 1
	}

	# reset working dir
	$working_dir = "$psscriptroot\tmp\$name"
	if(test-path $working_dir) {
		rm -r -force $working_dir
	}

	# set up
	cp $fixtures $working_dir -r

	return $working_dir
}