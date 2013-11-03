# Usage: scoop help <command>
# Summary: Show help for a command
param($cmd)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\commands.ps1"
. "$psscriptroot\..\lib\help.ps1"

function print_help($cmd) {
	$file = gc (relpath ".\scoop-$cmd.ps1") -raw

	$usage = usage $file
	$summary = summary $file
	$help = help $file

	if($usage) { "$usage`n" }
	if($help) { $help }
}

function print_summaries {
	$commands = @{}

	command_files | % {
		$command = command_name $_
		$summary = summary (gc (relpath $_) -raw )
		if(!($summary)) { $summary = '' }
		$commands.add("$command ", $summary) # add padding
	}

	$commands.getenumerator() | sort name | ft -hidetablehead -autosize -wrap
}

$commands = commands

if(!($cmd)) {
	"usage: scoop <command> [<args>]

Some useful commands are:"
	print_summaries
	"type 'scoop help <command>' to get help for a specific command"
} elseif($commands -contains $cmd) {
	print_help $cmd
} else {
	"scoop help: no such command '$cmd'"; exit 1
}

exit 0

