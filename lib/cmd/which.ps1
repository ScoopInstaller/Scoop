# Usage: scoop which <command>
# Summary: Locate a program path
# Help: Finds the path to a program that was installed with Scoop
param($command)
. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve '..\help.ps1')

if(!$command) { 'ERROR: <command> missing'; my_usage; exit 1 }

$gcm = gcm $command
if(!$gcm) { "$command not found"; exit 1 }

$path = $gcm.path
$abs_shimdir = "$(resolve-path $shimdir)"

if("$path" -like "$abs_shimdir*") {
	$shimtext = gc $path
	$shimtext | sls '(?m)^\$path = ''([^'']+)''' | % { $_.matches[0].groups[1].value }
} else {
	"(non-scoop) $path"
}