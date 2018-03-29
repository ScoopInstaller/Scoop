# Usage: scoop info <app>
# Summary: Display information about the app
param($app)

. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"

reset_aliases

$global = $opt.g -or $opt.global

if ($app) {
    $app, $bucket = app $app
    $status = app_status $app $global
    if ($status.installed) {
        $current_version = current_version $app $global
        $manifest = installed_manifest $app $current_version $global

        if ($bucket) {
            $manifest = find_manifest $app $bucket
        }

        if ($manifest) {
            $install = install_info $app $current_version $global
            $bucket = $install.bucket
            $url = $install.url
            $versions = versions $app $global
            $latest_version = latest_version $app $bucket $url

            Write-Output "$($app): $($latest_version)"
            if (![string]::isnullorempty($manifest.description)) {
                Write-Output "$($manifest.description)"
            }
            Write-Output "Home: $($manifest.homepage)"

            Write-Output "Installed:"
            $versions | ForEach-Object {
                $version = $_
                $dir = versiondir $app $version $global
                Write-Output "  $($dir)"
            }

            if ($url) {
                Write-Output "From: $($url)"
            } else {
                $from = manifest_path $app $bucket
                Write-Output "From: $($from)"
            }
        } else {
            if ($bucket) {
                abort "Could not find manifest for '$bucket/$app'."
            } else {
                abort "Could not find manifest for '$app'."
            }
        }
    } else {
        $manifest = manifest $app $bucket
        if ($manifest) {
            Write-Output "$($app): $($manifest.version)"
            if (![string]::isnullorempty($manifest.description)) {
                Write-Output "$($manifest.description)"
            }
            Write-Output "Home: $($manifest.homepage)"
            Write-Output "Not installed"
            $from = manifest_path $app $bucket
            Write-Output "From: $($from)"
        } else {
            if ($bucket) {
                abort "Could not find manifest for '$bucket/$app'."
            } else {
                abort "Could not find manifest for '$app'."
            }
        }
    }
} else { my_usage }

exit 0
