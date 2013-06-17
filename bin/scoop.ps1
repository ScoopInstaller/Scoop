param($cmd)

. "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"
. (resolve '..\lib\commands')

$commands = commands

echo $cmd
exit

if (@($null, '-h', '--help') -contains $cmd) { exec 'help' $args }
elseif ($commands -contains $cmd) { exec $cmd $args }
else { "scoop: '$cmd' isn't a scoop command. See 'scoop help'"; exit 1 }