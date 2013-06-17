# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)

$manifest = manifest $app
if(!$manifest) { abort "couldn't find manifest for '$app'" }
if(installed $app) { abort "'$app' is already installed"}

$appdir = appdir $app
mkdir $appdir > $null
$appdir = resolve-path $appdir

echo "downloading $($manifest.url)..."
$fname = split-path $manifest.url -leaf
dl $manifest.url "$appdir\$fname"

# todo: unzip?

# create bin stubs
$manifest.bin | % {
    echo "creating stub for $_ in ~\appdata\local\bin"
    
    # check valid bin
    $binpath = full_path "$appdir\$_"
    if($binpath -notmatch "^$([regex]::escape("$appdir\"))") {
        abort "error in manifest: bin '$_' is outside the app directory"
    }
    if(!(test-path $binpath)) { abort "can't stub $_`: file doesn't exist"}

    stub "$appdir\$_"
}

success "$app was succesfully installed"