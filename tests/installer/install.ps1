# Designed to be run manually to help figure out parameters for installers
# e.g. `tests\installer\install <app> [64bit|32bit] [-help]`
#
# * Knows about MSI and InnoSetup.
# * Will make use of scoop's manifest and download cache so you don't have to
#     keep track of the installer file.
# * Passing the -help switch should show the installer's help popup
#
# 
# How to silence the UAC prompt:
#   http://csi-windows.com/blog/all/27-csi-news-general/335-how-to-silence-the-uac-prompt-for-per-machine-msi-packages-for-non-admins
#
# MSIINSTALLPERUSER
#   http://msdn.microsoft.com/en-us/library/windows/desktop/dd408007(v=vs.85).aspx

param($app, $architecture='64bit',[switch]$help)

if(!$app) {
	"app is required"; exit 1;
}

. "$psscriptroot\..\..\lib\core.ps1"
. (relpath ..\..\lib\manifest.ps1)
. (relpath ..\..\lib\buckets.ps1)
. (relpath ..\..\lib\versions.ps1)
. (relpath ..\..\lib\install.ps1)

# override to use dev version for manifest
$scoopdir = relpath '..\..\'

$dir = fullpath (relpath .\tmp)
$manifest = manifest $app

$version = $manifest.version
$url = url $manifest $architecture
$fname = split-path $url -leaf

dl_with_cache $app $version $url "$dir\$fname"

if($fname -match '\.msi$') {
	$exe = 'msiexec'
	$file = resolve-path "$dir\$fname"
	$log = "$dir\$($app)_log.txt"
	$arg = @("/i `"$file`"", "/qb-!", "/norestart", "ALLUSERS=2", "MSIINSTALLPERUSER=1", "INSTALLDIR=`"$dir\install_$app`"", "/lvp `"$log`"")
	if($help) { $arg = '/?' }
	$installed = run $exe $arg "testing $fname..."
	"installed: $installed"

	$logtext = gc $log
	$logtext | sls '^Property\((?:S|C)\): ([A-Z]+) = ([^\n]*)' -casesensitive | % {
		$match = $_.matches[0]; $name = $match.groups[1]; $val = $match.groups[2];
		"$name`: $val"
	}

	$code = $logtext | sls "ProductCode = ([^\n]+)" | % { $_.matches[0].groups[1].value } | select -first 1
	echo "product code: $code"
} elseif($fname -match '\.exe$') {
	# assume innosetup
	echo "assuming innosetup"
	$exe = "$dir\$fname"
	$arg = @("/dir=`"$dir\install_$app`"", "/log=`"$dir\$($app)_log.txt`"", "/saveinf=`"$dir\$($app)_inf.txt`"", "/noicons", "/SP-", '/verysilent')
	if($help) { $arg = '/?' }
	$installed = run $exe $arg "testing $fname..."
} else { abort "no MSI or installer found"}