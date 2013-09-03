# Usage: scoop which <command>
# Summary: Locate a program path
# Help: Finds the path to a program that was installed with Scoop
param($command)
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"

if(!$command) { 'ERROR: <command> missing'; my_usage; exit 1 }

try { $gcm = gcm $command -ea stop } catch { }
if(!$gcm) { [console]::error.writeline("'$command' not found"); exit 3 }

$path = "$($gcm.path)"
$usershims = "$(resolve-path $(shimdir $false))"
$globalshims = "$(resolve-path $(shimdir $true))"

if($path -like "$usershims*" -or $path -like "$globalshims*") {
	$shimtext = gc $path
	$shimtext | sls '(?m)^\$path = ''([^'']+)''' | % { $_.matches[0].groups[1].value }
} else {
	[console]::error.writeline("not a scoop shim")
	$path
	exit 2
}

exit 0