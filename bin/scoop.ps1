#requires -v 3
param(
    [parameter(mandatory=$false)][string] $__CMDenvpipe = $null,
    [parameter(mandatory=$false,position=0)] $__cmd,
    [parameter(ValueFromRemainingArguments=$true)][array] $__args = @()
    )

set-strictmode -off

. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\commands')

$env:SCOOP__CMDenvpipe = $__CMDenvpipe

reset_aliases

$commands = commands

if (@($null, '-h', '--help', '/?') -contains $__cmd) { exec 'help' $__args }
elseif ($commands -contains $__cmd) { exec $__cmd $__args }
else { "scoop: '$__cmd' isn't a scoop command. See 'scoop help'"; exit 1 }
