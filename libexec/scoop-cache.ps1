# Usage: scoop cache show|rm [app]
# Summary: Show or clear the download cache
# Help: Scoop caches downloads so you don't need to download the same files
# when you uninstall and re-install the same version of an app.
#
# You can use
#     scoop cache show
# to see what's in the cache, and
#     scoop cache rm <app> to remove downloads for a specific app.
#
# To clear everything in your cache, use:
#     scoop cache rm *
param($cmd, $app)

. "$PSScriptRoot\..\lib\help.ps1"

reset_aliases

function cacheinfo($file) {
    $app, $version, $url = $file.name -split '#'
    return New-Object psobject -Property @{ Name=$app; Version=$version; Length=$file.length; URL=$url }
}

function cacheshow($app) {
    $files = @(Get-ChildItem "$cachedir" | Where-Object { $_.name -match "^$app" })
    $total_length = ($files | Measure-Object length -sum).sum -as [double]

    $files | ForEach-Object { cacheinfo $_ } | Select-Object Name, Version, Length, URL

    Write-Host "Total: $($files.length) $(pluralize $files.length 'file' 'files'), $(filesize $total_length)"
}

switch($cmd) {
    'rm' {
        if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }
        Remove-Item "$cachedir\$app#*"
        if(test-path("$cachedir\$app.txt")) {
            Remove-Item "$cachedir\$app.txt"
        }
    }
    'show' {
        cacheshow $app
    }
    '' {
        cacheshow
    }
    default {
        my_usage
    }
}

exit 0
