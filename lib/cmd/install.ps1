# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)

$manifest = manifest $app
if(!$manifest) { abort "couldn't find manifest for '$app'" }
if(installed $app) { abort "'$app' is already installed. "}

$appdir = appdir $app
mkdir $appdir > $null
$appdir = resolve-path $appdir

# assume powershell for now!
echo "downloading $($manifest.url)..."
dl $manifest.url "$appdir\$app.ps1"

# binstub
echo "creating stub in ~\appdata\local\bin"
stub "$appdir\$app.ps1"

success "$app was succesfully installed!"