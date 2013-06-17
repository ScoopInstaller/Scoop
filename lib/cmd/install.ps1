# Usage: scoop install <app>
# Summary: Install an app
# Help: e.g. `scoop install git`
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"
. (resolve ../manifest.ps1)
. (resolve ../help_comments.ps1)

if(!$app) { "ERROR: <app> missing"; my_usage; exit }

$manifest = manifest $app
if(!$manifest) { abort "couldn't find manifest for '$app'" }
if(installed $app) { abort "'$app' is already installed"}

$appdir = appdir $app
mkdir $appdir > $null
$appdir = resolve-path $appdir
$delete_dl_file = $false;

echo "downloading $($manifest.url)..."
$fname = split-path $manifest.url -leaf
dl $manifest.url "$appdir\$fname"

# unzip
if($fname -match '\.zip') {
	unzip "$appdir\$fname" $appdir
	$delete_dl_file = $true
}

# installer
if($manifest.installer) {
	$arguments = $manifest.installer.args
	$a = @()
	if($arguments) { $arguments | % { $a += (format $_ @{'appdir'=$appdir}) } }
	
	write-host "installing..." -nonewline
	start-process "$appdir\$fname" -wait -ea 0 -arg $a
	write-host "done"
	$delete_dl_file = $true
}

if($delete_dl_file) {
	rm "$appdir\$fname"
}

# create bin stubs
$manifest.bin | ?{ $_ -ne $null } | % {
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