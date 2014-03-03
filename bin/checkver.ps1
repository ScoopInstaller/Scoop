param($app, $dir)
# checks websites for newer versions using an (optional) regular expression defined in the manifest
# use $dir to specify a manifest directory to check from, otherwise ./bucket is used

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

$wc = new-object net.webclient

$search = "*"
if($app) { $search = $app }

gci $dir "$search.json" | % {
	$json = parse_json "$dir\$_"
	if($json.checkver) {
		write-host "checking $(strip_ext (fname $_))..." -nonewline
		$expected_ver = $json.version

		$url = $json.checkver.url
		if(!$url) { $url = $json.homepage }

		$regexp = $json.checkver.re
		if(!$regexp) { $regexp = $json.checkver }

		$page = $wc.downloadstring($url)

		if($page -match $regexp) {
			$ver = $matches[1]
			if($ver -eq $expected_ver) {
				write-host "$ver" -f darkgreen
			} else {
				write-host "$ver" -f darkred -nonewline
				write-host " (scoop version is $expected_ver)"
			}
			
		} else {
			write-host "couldn't match '$regexp' in $url" -f darkred
		}

	}
}