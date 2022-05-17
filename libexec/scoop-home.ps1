# Usage: scoop home <app>
# Summary: Opens the app homepage
param($app)

. "$PSScriptRoot\..\lib\manifest.ps1" # 'Find-Manifest' (indirectly)

if ($app) {
    $null, $manifest, $bucket, $null = Find-Manifest $app
    if ($manifest) {
        if ($manifest.homepage) {
            Start-Process $manifest.homepage
        } else {
            abort "Could not find homepage in manifest for '$app'."
        }
    } else {
        abort "Could not find manifest for '$app'."
    }
} else {
    my_usage
    exit 1
}

exit 0
