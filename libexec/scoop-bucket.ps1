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
#     scoop bucket add extras https://github.com/ScoopInstaller/Extras.git
#
# Since the 'extras' bucket is known to Scoop, this can be shortened to:
#     scoop bucket add extras
#
# To list all known buckets, use:
#     scoop bucket known
param($cmd, $name, $repo)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

$usage_add = 'usage: scoop bucket add <name> [<repo>]'
$usage_rm = 'usage: scoop bucket rm <name>'

switch ($cmd) {
    'add' {
        if (!$name) {
            '<name> missing'
            $usage_add
            exit 1
        }
        if (!$repo) {
            $repo = known_bucket_repo $name
            if (!$repo) {
                "Unknown bucket '$name'. Try specifying <repo>."
                $usage_add
                exit 1
            }
        }
        add_bucket $name $repo
    }
    'rm' {
        if (!$name) {
            '<name> missing'
            $usage_rm
            exit 1
        }
        rm_bucket $name
    }
    'list' {
        list_buckets
    }
    'known' {
        known_buckets
    }
    default {
        "scoop bucket: cmd '$cmd' not supported"
        my_usage
        exit 1
    }
}

exit 0
