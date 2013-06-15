param($cmd)

. "$(split-path $myinvocation.mycommand.path)\..\lib\init.ps1"

require '..\lib\commands'

all_commands