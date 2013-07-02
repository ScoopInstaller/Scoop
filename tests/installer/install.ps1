param($app, $architecture='64bit',[switch]$help)

. "$psscriptroot\..\..\lib\core.ps1"
. (relpath ..\..\lib\manifest.ps1)
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
	$arg = @("/i `"$file`"", "/qb-!", "ALLUSERS=''", "INSTALLDIR=`"$dir\install_$app`"", "/lvp `"$log`"")
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