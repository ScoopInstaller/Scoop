# Usage: scoop help <cmd>
# Summary: show help for a command
param($cmd)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve '..\commands.ps1')

function usage($filetext) {
    $filetext | sls '(?m)^#\s*Usage:\s*([^\n]*)$' | % { $_.matches[0].groups[1] }
}

function summary($filetext) {
    $filetext | sls '(?m)^#\s*Summary:\s*([^\n]*)$' | % { $_.matches[0].groups[1] }
}

function print_help($cmd) {
    $filetext = gc (resolve ".\$cmd.ps1") -raw

    $usage = usage $filetext
    $summary = summary $filetext
    # $help = help $filetext

    if($usage) { echo "usage: $usage" }
    if($help) { echo $help }
}

$commands = commands

if($commands -contains $cmd) {
    print_help $cmd
} else {
    echo "scoop help: no such command '$cmd'"
}

