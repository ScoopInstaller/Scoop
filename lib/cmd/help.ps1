# Usage: scoop help <command>
# Summary: Show help for a command
param($cmd)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve '..\commands.ps1')
. (resolve '..\help_comments.ps1')

function print_help($cmd) {
	$file = gc (resolve ".\$cmd.ps1") -raw

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
		$summary = summary (gc (resolve $_) -raw )
		if(!($summary)) { $summary = '' }
		$commands.add("$command ", $summary) # add padding
	}

	$commands | ft -hidetablehead -autosize -wrap
}

$commands = commands

if(!($cmd)) {
	"usage: scoop <command> [<args]

Some useful commands are:"
	print_summaries
	"type 'scoop help <command>'' to get help for a specific command"
} elseif($commands -contains $cmd) {
	print_help $cmd
} else {
	"scoop help: no such command '$cmd'"
}

