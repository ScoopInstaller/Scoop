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
. "$psscriptroot\..\lib\help.ps1"

$usage_add = "usage: scoop add <name> <repo>"

function add_bucket($name, $repo) {

}

switch($cmd) {
    "add" {
        if(!$name) { "<name> missing"; $usage_add; exit 1 }
        if(!$repo) { "<repo> missing"; $usage_add; exit 1 }
        add_bucket($name, $repo)
    }
    default { "scoop bucket: cmd '$cmd' not supported"; my_usage; exit 1 }
}