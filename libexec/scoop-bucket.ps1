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

reset_aliases

$usage_add = "usage: scoop bucket add <name> [<repo>]"
$usage_rm = "usage: scoop bucket rm <name>"

function list_buckets {
    $buckets = @()

    foreach ($bucket in Get-LocalBucket) {
        $source = Find-BucketDirectory $bucket -Root
        $manifests = (
            Get-ChildItem "$source\bucket" -Force -Recurse -ErrorAction SilentlyContinue |
            Measure-Object | Select-Object -ExpandProperty Count
        )
        $updated = 'N/A'
        if ((Test-Path (Join-Path $source '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
            $updated = git -C $source log --format='%aD' -n 1 | Get-Date
            $source = git -C $source config remote.origin.url
        } else {
            $updated = (Get-Item "$source\bucket").LastWriteTime
            $source = friendly_path $source
        }
        $buckets += New-Object PSObject -Property @{
            Name      = $bucket
            Source    = $source
            Updated   = $updated
            Manifests = $manifests
        }
    }
    return $buckets | Select-Object Name, Source, Updated, Manifests
}

switch ($cmd) {
    'add' { add_bucket $name $repo }
    'rm' { rm_bucket $name }
    'list' { list_buckets }
    'known' { known_buckets }
    default { "scoop bucket: cmd '$cmd' not supported"; my_usage; exit 1 }
}

exit 0
