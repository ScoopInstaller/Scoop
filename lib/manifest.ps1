function manifest_path($app) { (relpath "..\bucket\$app.json") }

function parse_json($path) {
	if(!(test-path $path)) { return $null }
	gc $path -raw | convertfrom-json
}

function url_manifest($url) {
	$str = (new-object net.webclient).downloadstring($url)
	if(!$str) { return $null }
	$str | convertfrom-json
}

function manifest($app, $url) {
	if($url) { url_manifest $url }
	else { parse_json (manifest_path $app) }
}

function save_installed_manifest($app, $dir, $url) {
	if($url) { (new-object net.webclient).downloadstring($url) > "$dir\manifest.json" }
	else { cp (manifest_path $app) "$dir\manifest.json" }
}

function installed_manifest($app, $version) {
	parse_json "$(versiondir $app $version)\manifest.json"
}

function save_install_info($info, $dir) {
	$nulls = $info.keys | ? { $info[$_] -eq $null }
	$nulls | % { $info.remove($_) } # strip null-valued

	$info | convertto-json | out-file "$dir\install.json"
}

function install_info($app, $version) {
	$path = "$(versiondir $app $version)\install.json"
	if(!(test-path $path)) { return $null }
	parse_json $path
}

function architecture {
	if([intptr]::size -eq 8) { return "64bit" }
	"32bit"
}

function arch_specific($prop, $manifest, $architecture) {
	if($manifest.$prop) { return $manifest.$prop }

	if($manifest.architecture) {
		$manifest.architecture.$architecture.$prop
	}
}

function apps_in_bucket($path) {
	gci $path | ? { $_.name.endswith('.json') } | % { $_ -replace '.json$', '' }
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function msi($manifest, $arch) { arch_specific 'msi' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }