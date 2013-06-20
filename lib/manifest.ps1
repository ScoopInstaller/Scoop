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

function url($manifest) {
	if($manifest.url) { return $manifest.url } # only one URL

	if($manifest.urls) {
		$manifest.urls.(architecture)
	}
}