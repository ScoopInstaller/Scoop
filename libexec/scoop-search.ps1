# Usage: scoop search [query]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
# 
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\buckets.ps1')
. (relpath '..\lib\manifest.ps1')
. (relpath '..\lib\versions.ps1')

function bin_match($manifest, $query) {
	if(!$manifest.bin) { return $false }
	foreach($bin in $manifest.bin) {
		$fname = split-path $bin -leaf
		if((strip_ext $fname) -match $query) { return $fname }
	}
	$false
}

function search_bucket($bucket, $query) {
	$apps = apps_in_bucket (bucketdir $bucket) | % {
		@{ name = $_ }
	}

	if($query) { $apps = $apps | ? {
		if($_.name -match $query) { return $true }
		$bin = bin_match (manifest $_.name) $query
		if($bin) {
			$_.bin = $bin; return $true;
		}
	} }
	$apps | % { $_.version = (latest_version $_.name $bucket); $_ }
}

@($null) + @(buckets) | % { # $null is main bucket
	$res = search_bucket $_ $query
	if($res) {
		$name = "$_"
		if(!$_) { $name = "main" }
		
		"$name bucket:"
		$res | % {
			$item = "  $($_.name) ($($_.version))"
			if($_.bin) { $item += " --> includes '$($_.bin)'" }
			$item
		}
		""
	}
}

exit 0