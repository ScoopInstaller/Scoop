# Usage: scoop cache show|rm|tidy [app(s)]
# Summary: Show or clear the download cache
# Help: Scoop caches downloads so you don't need to download the same files
# when you uninstall and re-install the same version of an app.
#
# You can use
#     scoop cache show
# to see what's in the cache, and
#     scoop cache rm <app> to remove downloads for a specific app.
# Or to only remove downloads that older,
#     scoop cache tidy <app> removes ones older than a month, keeping the two most recent
#
# To clear everything in your cache, use:
#     scoop cache rm *
# To remove older items for all apps, use:
#     scoop cache tidy *
# You can also use the `-a/--all` switch in place of `*` here

param($cmd)

. "$PSScriptRoot\..\lib\cache.ps1"

function cacheinfo($file) {
    $app, $version, $url = $file.Name -split '#'
    New-Object PSObject -Property @{ Name = $app; Version = $version; Length = $file.Length }
}

function cacheshow($app) {
    if (!$app -or $app -eq '*') {
        $app = '.*?'
    } else {
        $app = '(' + ($app -join '|') + ')'
    }
    $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match)
    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum

    $files | ForEach-Object { cacheinfo $_ } | Select-Object Name, Version, Length

    Write-Host "Total: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalLength)" -ForegroundColor Yellow
}

function cacheremove($app) {
    if (!$app) {
        'ERROR: <app(s)> missing'
        my_usage
        exit 1
    } elseif ($app -eq '*' -or $app -eq '-a' -or $app -eq '--all') {
        $files = @(Get-ChildItem $cachedir)
    } else {
        $app = '(' + ($app -join '|') + ')'
        $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match)
    }
    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum

    $files | ForEach-Object {
        $curr = cacheinfo $_
        Write-Host "Removing $($_.Name)..."
        Remove-Item $_.FullName
        if(Test-Path "$cachedir\$($curr.Name).txt") {
            Remove-Item "$cachedir\$($curr.Name).txt"
        }
    }

    Write-Host "Deleted: $($files.Length) $(pluralize $files.Length 'file' 'files'), $(filesize $totalLength)" -ForegroundColor Yellow
}

function cache_remove_older($app) {
    if (!$app) {
        'ERROR: <app(s)> missing'
        my_usage
        exit 1
    } elseif ($app -eq '*' -or $app -eq '-a' -or $app -eq '--all') {
        $files = @(Get-ChildItem $cachedir)
        $totalLength = ($files | Measure-Object -Property Length -Sum).Sum
        # Get all apps with cache, and remove their older packages
        $apps = @()
        $files | ForEach-Object {
            $apps += ($_ -split '#', 2)[0]
        }
        $apps = $apps | Select-Object -Unique

        $apps | ForEach-Object {
            tidy_cache $_
        }

        $filesAfter = @(Get-ChildItem $cachedir)
        $totalLengthAfter = ($filesAfter | Measure-Object -Property Length -Sum).Sum
        $filesRemoved = $files.Length - $filesAfter.length
        $sizeRemoved = $totalLength - $totalLengthAfter
        Write-Host "Deleted: $($filesRemoved) $(pluralize $filesRemoved 'file' 'files'), $(filesize $sizeRemoved)" -ForegroundColor Yellow
    } else {
        tidy_cache $app $true
    }
}

switch($cmd) {
    'rm' {
        cacheremove $Args
    }
    'tidy' {
        cache_remove_older $Args
    }
    'show' {
        cacheshow $Args
    }
    default {
        cacheshow (@($cmd) + $Args)
    }
}

exit 0
