# Usage: scoop bucket add|list|known|rm [<args>]
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
#
# To list all known buckets, use:
#     scoop bucket known
param($cmd, $name, $repo)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\git.ps1"

reset_aliases

$usage_add = "usage: scoop bucket add <name> [<repo>]"
$usage_rm = "usage: scoop bucket rm <name>"

function add_bucket($name, $repo) {
    if(!$name) { "<name> missing"; $usage_add; exit 1 }
    if(!$repo) {
        $repo = known_bucket_repo $name
        if(!$repo) { "Unknown bucket '$name'. Try specifying <repo>."; $usage_add; exit 1 }
    }

    $git = try { gcm 'git' -ea stop } catch { $null }
    if(!$git) {
        abort "Git is required for buckets. Run 'scoop install git'."
    }

    $dir = bucketdir $name
    if(test-path $dir) {
        warn "The '$name' bucket already exists. Use 'scoop bucket rm $name' to remove it."
        exit 0
    }

    write-host 'Checking repo... ' -nonewline
    $out = git_ls_remote $repo 2>&1
    if($lastexitcode -ne 0) {
        abort "'$repo' doesn't look like a valid git repository`n`nError given:`n$out"
    }
    write-host 'ok'

    ensure $bucketsdir > $null
    $dir = ensure $dir
    git_clone "$repo" "`"$dir`""
    success "The $name bucket was added successfully."
}

function rm_bucket($name) {
    if(!$name) { "<name> missing"; $usage_rm; exit 1 }
    $dir = bucketdir $name
    if(!(test-path $dir)) {
        abort "'$name' bucket not found."
    }

    rm $dir -r -force -ea stop
}

function list_buckets {
    buckets
}

function known_buckets {
    known_bucket_repos |% { $_.psobject.properties | select -expand 'name' }
}

switch($cmd) {
    "add" { add_bucket $name $repo }
    "rm" { rm_bucket $name }
    "list" { list_buckets }
    "known" { known_buckets }
    default { "scoop bucket: cmd '$cmd' not supported"; my_usage; exit 1 }
}

exit 0
