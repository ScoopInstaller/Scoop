. "$(split-path $myinvocation.mycommand.path)\..\..\lib\core.ps1"

$cmd = command $myinvocation

$cmd, (rawargs $myinvocation)