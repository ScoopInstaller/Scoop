# Usage: scoop help <command>
# Summary: Show help for a command
param($cmd)

function print_help($cmd) {
    $file = Get-Content (command_path $cmd) -Raw

    $usage = usage $file
    $help = scoop_help $file

    if ($usage) { "$usage`n" }
    if ($help) { $help }
}

function print_summaries {
    $commands = @()

    command_files | ForEach-Object {
        $command = [ordered]@{}
        $command.Command = command_name $_
        $command.Summary = summary (Get-Content (command_path $command.Command))
        $commands += [PSCustomObject]$command
    }

    $commands
}

$commands = commands

if(!($cmd)) {
    Write-Host "Usage: scoop <command> [<args>]

Available commands are listed below.

Type 'scoop help <command>' to get more help for a specific command."
    print_summaries
} elseif($commands -contains $cmd) {
    print_help $cmd
} else {
    warn "scoop help: no such command '$cmd'"
    exit 1
}

exit 0
