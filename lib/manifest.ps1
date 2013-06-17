function manifest($app) {
	$path = (resolve "..\bucket\$app.json")
	if(!(test-path $path)) { return $null }
	return gc $path -raw | convertfrom-json
}