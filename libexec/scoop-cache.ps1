# Usage: scoop cache show|rm [app(s)]
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
param($cmd)

. "$PSScriptRoot\..\lib\help.ps1"

function cacheinfo($file) {
    $app, $version, $url = $file.Name -split '#'
    New-Object PSObject -Property @{ Name = $app; Version = $version; Length = $file.Length; URL = $url }
}

function cacheshow($app) {
    if (!$app -or $app -eq '*') {
        $app = '.*?'
    } else {
        $app = '(' + ($app -join '|') + ')'
    }
    $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match)
    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum

    $files | ForEach-Object { cacheinfo $_ } | Select-Object Name, Version, Length, URL

    Write-Host "Total: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalLength)" -ForegroundColor Yellow
}

function cacheremove($app) {
    if (!$app) {
        'ERROR: <app(s)> missing'
        my_usage
        exit 1
    } elseif ($app -eq '*') {
        $files = @(Get-ChildItem $cachedir)
    } else {
        $app = '(' + ($app -join '|') + ')'
        $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match)
    }
    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum

    $files | ForEach-Object {
        $curr = cacheinfo $_
        Write-Host "Removing $($curr.URL)..."
        Remove-Item $_.FullName
        if(Test-Path "$cachedir\$($curr.Name).txt") {
            Remove-Item "$cachedir\$($curr.Name).txt"
        }
    }

    Write-Host "Deleted: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalLength)" -ForegroundColor Yellow
}

switch($cmd) {
    'rm' {
        cacheremove $Args
    }
    'show' {
        cacheshow $Args
    }
    default {
        cacheshow (@($cmd) + $Args)
    }
}

exit 0
