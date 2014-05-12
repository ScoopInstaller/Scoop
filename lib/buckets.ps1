$bucketsdir = "$scoopdir\buckets"

function bucketdir($name) {
	if(!$name) { return relpath "..\bucket" } # main bucket

	"$bucketsdir\$name"
}

function known_bucket_repo($name) {
	$dir = versiondir 'scoop' 'current'
	$json = "$dir\buckets.json"
	$buckets = gc $json -raw | convertfrom-json -ea stop
	$buckets.$name
}

function apps_in_bucket($dir) {
	gci $dir | ? { $_.name.endswith('.json') } | % { $_ -replace '.json$', '' }
}

function buckets {
	$buckets = @()
	if(test-path $bucketsdir) {
		gci $bucketsdir | % { $buckets += $_.name }
	}
	$buckets
}

function find_manifest($app) {
	$buckets = @($null) + @(buckets) # null for main bucket
	foreach($bucket in $buckets) {
		$manifest = manifest $app $bucket
		if($manifest) {	return $manifest, $bucket }
	}
}