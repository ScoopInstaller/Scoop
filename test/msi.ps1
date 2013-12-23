param($app, $url, $architecture='64bit',[switch]$help)

if(!$app) {
	"app is required"; exit 1;
}

. "$psscriptroot\..\lib\core.ps1"
. (relpath ..\lib\manifest.ps1)
. (relpath ..\lib\buckets.ps1)
. (relpath ..\lib\versions.ps1)
. (relpath ..\lib\install.ps1)

# override to use dev version for manifest
$scoopdir = relpath '..\'

$dir = fullpath (relpath .\tmp)
if(!(test-path $dir)) { mkdir $dir > $null }
$manifest = manifest $app $null $url

$version = $manifest.version
$dlurl = url $manifest $architecture
$fname = split-path $dlurl -leaf

dl_with_cache $app $version $dlurl "$dir\$fname"

if($fname -notmatch '\.msi$') {
	abort "not an msi"
}

if(test-path "$dir\$app") { rm -r -force "$dir\$app" }
$null = mkdir "$dir\$app"

# exits immediately
# msiexec /a $dir\$fname /qb TARGETDIR="$dir\$app"
$ok = run 'msiexec' @('/a', "$dir\$fname", '/qn', "TARGETDIR=`"$dir\$app`"") "extracting msi..."
if($ok) {
	"extracted sussfully"
} else {
	"extraction failed"
}