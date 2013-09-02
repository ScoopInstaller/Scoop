function fail($msg) {
	$invoked = (get-variable -scope 1 myinvocation).value

	$script = split-path $invoked.scriptname -leaf
	$line = $invoked.scriptlinenumber
	write-host "$msg ($script line $line)" -f red
    write-host $invoked.positionmessage
}

function is_equal($a, $b) {
	if($a -ne $b) { fail "$a != $b" }
}
function is_not_equal($a, $b) {
	if($a -eq $b) { fail "$a == $b" }
}