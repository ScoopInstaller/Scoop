function manifest($app) {
	$path = (resolve "..\bucket\$app.json")
	if(!(test-path $path)) { return $null }
	return gc $path -raw | convertfrom-json
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