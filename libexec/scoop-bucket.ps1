# Usage: scoop bucket add|list|rm [<args>]
# Summary: Manage Scoop buckets
# Help: Add, list or remove buckets.
#
# Buckets are repositories of apps available to install. Scoop comes with
# a default bucket, but you can also add buckets that you or others have
# published.
#
# To add a bucket:
#     scoop bucket add <name> [<repo>]
#
# e.g.:
#     scoop bucket add extras https://github.com/lukesampson/scoop-extras.git
#
# Since the 'extras' bucket is known to Scoop, this can be shortened to:
#     scoop bucket add extras
param($cmd, $name, $repo)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\help.ps1"

$usage_add = "usage: scoop bucket add <name> [<repo>]"
$usage_rm = "usage: scoop bucket rm <name>"

function add_bucket($name, $repo) {
	if(!$name) { "<name> missing"; $usage_add; exit 1 }
	if(!$repo) {
		$repo = known_bucket_repo $name
		if(!$repo) { "unknown bucket '$name': try specifying <repo>"; $usage_add; exit 1 }
	}

	$git = try { gcm 'git' -ea stop } catch { $null }
	if(!$git) {
		abort "git is required for buckets. run 'scoop install git'."
	}

	$dir = bucketdir $name
	if(test-path $dir) {
		abort "'$name' bucket already exists. use 'scoop bucket rm $name' to remove it."
	}

	write-host 'checking repo...' -nonewline
	git ls-remote $repo 2>&1 > $null
	if($lastexitcode -ne 0) {
		abort "'$repo' doesn't look like a valid git repository"
	}
	write-host 'ok'

	ensure $bucketsdir > $null
	$dir = ensure $dir
	git clone "$repo" "$dir"
	success "$name bucket was added successfully"
}

function rm_bucket($name) {
	if(!$name) { "<name> missing"; $usage_rm; exit 1 }
	$dir = bucketdir $name
	if(!(test-path $dir)) {
		abort "'$name' bucket not found"
	}

	rm $dir -r -force -ea stop
}

function list_buckets {
	buckets
}

switch($cmd) {
	"add" { add_bucket $name $repo }
	"rm" { rm_bucket $name }
	"list" { list_buckets }
	default { "scoop bucket: cmd '$cmd' not supported"; my_usage; exit 1 }
}