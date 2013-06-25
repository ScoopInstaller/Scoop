function manifest_path($app) { (resolve "..\bucket\$app.json") }

function parse_manifest($path) {
	if(!(test-path $path)) { return $null }
	gc $path -raw | convertfrom-json
}

function manifest($app) {
	parse_manifest (manifest_path $app)	
}

function installed_manifest($app, $version) {
	parse_manifest "$(versiondir $app $version)\manifest.json"
}

function architecture {
	if([intptr]::size -eq 8) { return "64bit" }
	"32bit"
}

function arch_specific($prop, $manifest) {
	if($manifest.$prop) { return $manifest.$prop }

	if($manifest.architecture) {
		$manifest.architecture.(architecture).$prop
	}
}

function url($manifest) { arch_specific 'url' $manifest }
function installer($manifest) { arch_specific 'installer' $manifest }
function uninstaller($manifest) { arch_specific 'installer' $manifest }
function msi($manifest) { arch_specific 'msi' $manifest }