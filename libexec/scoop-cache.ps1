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
# You can also use the `-a/--all` switch in place of `*` here

param($cmd)

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
        error '<app(s)> missing'
        my_usage
        exit 1
    } elseif ($app -eq '*' -or $app -eq '-a' -or $app -eq '--all') {
        $files = @(Get-ChildItem $cachedir)
    } else {
        # Escape the names, so that e.g. the dot in 'foo.bar' doesn't match other apps' files
        $app = '(' + (($app | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
        # Also match '<app>.txt', the aria2 input file left by an interrupted download
        $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app(#|\.txt$)" -Match)
    }
    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum

    $files | ForEach-Object {
        Write-Host "Removing $($_.Name)..."
        Remove-Item $_.FullName
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
