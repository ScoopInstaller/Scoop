# Usage: scoop which <command>
# Summary: Locate a program path
# Help: Finds the path to a program that was installed with Scoop
param($command)
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

if(!$command) { 'ERROR: <command> missing'; my_usage; exit 1 }

try { $gcm = gcm $command -ea stop } catch { }
if(!$gcm) { [console]::error.writeline("'$command' not found"); exit 3 }

$path = "$($gcm.path)"
$usershims = "$(resolve-path $(shimdir $false))"
$globalshims = fullpath (shimdir $true) # don't resolve: may not exist

if($path -like "$usershims*" -or $path -like "$globalshims*") {
	$shimtext = gc $path
    $exepath = $shimtext | sls '(?m)^\$path = (''|")([^\1]+)\1' | % { $_.matches[0].groups[2].value }
	friendly_path $exepath
} else {
	[console]::error.writeline("not a scoop shim")
	$path
	exit 2
}

exit 0