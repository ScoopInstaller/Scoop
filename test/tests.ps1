function fail($msg) {
	$invoked = (get-variable -scope 1 myinvocation).value

	$script = split-path $invoked.scriptname -leaf
	$line = $invoked.scriptlinenumber
	write-host "$msg ($script line $line)" -f red
}

function assert_eq($a, $b) {
	if($a -ne $b) { fail "$a != $b" }
}
function assert_neq($a, $b) {
	if($a -eq $b) { fail "$a == $b" }
}