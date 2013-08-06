# Usage: scoop bucket add|list|rm [<args>]
# Summary: Manage scoop buckets
# Help: Add, list or remove buckets.
#
# Buckets are repositories of apps available to install. Scoop comes with
# a default bucket, but you can also add buckets that you or others have
# published.
#
# To add a bucket:
#     scoop bucket add <name> <repo>
#
# e.g. `scoop bucket add extras https://github.com/lukesampson/scoop-extras.git`
param($cmd, $name, $repo)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\help.ps1"

$usage_add = "usage: scoop add <name> <repo>"

function add_bucket($name, $repo) {
    $git = try { gcm 'git' -ea stop } catch { $null }
    if(!$git) {
        abort "git is required for buckets. run 'scoop install git'."
    }

    git ls-remote $repo 2>&1 > $null
    if($lastexitcode -ne 0) {
        abort "$repo doesn't look like a valid Git repository"
    }

    $config = config
    if(!$config.buckets) { $config.buckets = @{} }
    if($config.buckets.$name) {
        abort "'$name' bucket already exists. use 'scoop bucket rm $name' to remove it."
    }

    $config.buckets.$name = $repo

    save_config $config
}

switch($cmd) {
    "add" {
        if(!$name) { "<name> missing"; $usage_add; exit 1 }
        if(!$repo) { "<repo> missing"; $usage_add; exit 1 }
        add_bucket $name $repo
    }
    default { "scoop bucket: cmd '$cmd' not supported"; my_usage; exit 1 }
}