# Usage: scoop help <command>
# Summary: Show help for a command
param($cmd)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\commands.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

reset_aliases

function print_help($cmd) {
    $file = Get-Content (command_path $cmd) -Raw

    $usage = usage $file
    $summary = summary $file
    $help = scoop_help $file

    if($usage) { "$usage`n" }
    if($help) { $help }
}

function print_summaries {
    $commands = @{}

    command_files | ForEach-Object {
        $command = command_name $_
        $summary = summary (Get-Content (command_path $command) -Raw)
        if(!($summary)) { $summary = '' }
        $commands.Add("$command ", $summary) # add padding
    }

    $commands.GetEnumerator() | Sort-Object name | Format-Table -HideTableHeaders -AutoSize -Wrap
}

$commands = commands

if(!($cmd)) {
    "Usage: scoop <command> [<args>]

Some useful commands are:"
    print_summaries
    "Type 'scoop help <command>' to get help for a specific command."
} elseif($commands -contains $cmd) {
    print_help $cmd
} else {
    "scoop help: no such command '$cmd'"; exit 1
}

exit 0

