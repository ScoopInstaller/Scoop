# for development, update the installed scripts to match local source
. "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"

$src = resolve-path (resolve "..")
$dir = ensure (versiondir 'scoop' 'current')

$dest = ensure "$dir\scoop-master" # scoop-master mimics the remote install

# make sure not running from the installed directory
if("$src" -eq "$dest") { abort "$(strip_ext $myinvocation.mycommand.name) is for development only" }

'copying files...'
cp "$src\*" $dest -recurse -force -exclude '.git'

echo 'creating stub...'
stub "$dir\scoop-master\bin\scoop.ps1"

ensure_scoop_in_path
success 'scoop was refreshed!'