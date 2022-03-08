# for development, update the installed scripts to match local source
. "$PSScriptRoot\..\lib\core.ps1"

$src = relpath ".."
$dest = ensure (versiondir 'scoop' 'current')

# make sure not running from the installed directory
if("$src" -eq "$dest") { abort "$(strip_ext $myinvocation.mycommand.name) is for development only" }

'copying files...'
$output = robocopy $src $dest /mir /njh /njs /nfl /ndl /xd .git tmp /xf .DS_Store last_updated

$output | Where-Object { $_ -ne "" }

Write-Output 'creating shim...'
shim "$dest\bin\scoop.ps1" $false

success 'scoop was refreshed!'
