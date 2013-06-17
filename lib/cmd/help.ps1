# Usage: scoop help <command>
# Summary: Show help for a command
param($cmd)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve '..\commands.ps1')

function usage($text) {
	$text | sls '(?m)^# Usage: ([^\n]*)$' | % { $_.matches[0].groups[1] }
}

function summary($text) {
	$text | sls '(?m)^# Summary: ([^\n]*)$' | % { $_.matches[0].groups[1] }
}

function help($text) {
	$help_lines = $text | sls '(?ms)^# Help:(.(?!^[^#]))*' | % { $_.matches[0].value; }
	$help_lines -replace '(?ms)^# (Help: )?', ''
}

function print_help($cmd) {
	$file = gc (resolve ".\$cmd.ps1") -raw

	$usage = usage $file
	$summary = summary $file
	$help = help $file

	if($usage) { echo "usage: $usage`n" }
	if($help) { echo $help }
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
	echo "usage: scoop <command> [<args]

Some useful commands are:"
	print_summaries
	echo "type scoop help <command> to get help for a command"
} elseif($commands -contains $cmd) {
	print_help $cmd
} else {
	echo "scoop help: no such command '$cmd'"
}

