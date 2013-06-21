# for development, update the installed scripts to match local source
. "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"

$src = resolve-path (resolve "..")
$dest = ensure (versiondir 'scoop' 'current')

# make sure not running from the installed directory
if("$src" -eq "$dest") { abort "$(strip_ext $myinvocation.mycommand.name) is for development only" }

'copying files...'
cp "$src\*" $dest -recurse -force -exclude '.git'

echo 'creating stub...'
stub "$dest\bin\scoop.ps1"

ensure_scoop_in_path
success 'scoop was refreshed!'