# Usage: scoop which <command>
# Summary: Locate a program path
# Help: Find where a program is actually installed, if it was installed with scoop.
param($command)
. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

$gcm = gcm $command
if(!$gcm) { "$command not found"; exit 1 }

$path = $gcm.path
$abs_bindir = "$(resolve-path $bindir)"

if("$path" -like "$abs_bindir*") {
	$stubtext = gc $path
	$stubtext | sls '(?m)^iex "&''([^'']+)''' | % { $_.matches[0].groups[1].value }
} else {
	"(non-scoop) $path"
}