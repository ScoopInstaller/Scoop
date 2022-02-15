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

reset_aliases

function cacheinfo($file) {
    $app, $version, $url = $file.name -split '#'
    return New-Object psobject -Property @{ Name=$app; Version=$version; Length=$file.length; URL=$url }
}

function cacheshow($app) {
    if (!$app) { $app = '*' }
    else { $app = '(' + ($app -join '|') + ')' }
    $files = @(Get-ChildItem "$cachedir" | Where-Object { $_.name.Split('#')[0] -match "^$app$" })
    $total_length = ($files | Measure-Object length -sum).sum -as [double]

    $files | ForEach-Object { cacheinfo $_ } | Select-Object Name, Version, Length, URL

    Write-Host "Total: $($files.length) $(pluralize $files.length 'file' 'files'), $(filesize $total_length)" -ForegroundColor Yellow
}

function cacheremove($app) {
    if (!$app) { 'ERROR: <app(s)> missing'; my_usage; exit 1 }
    elseif ($app -ne '*') { $app = '(' + ($app -join '|') + ')' }
    $files = @(Get-ChildItem "$cachedir" | Where-Object { $_.name.Split('#')[0] -match "^$app$" })
    $total_length = ($files | Measure-Object length -sum).sum -as [double]

    $files | ForEach-Object {
        $curr = cacheinfo $_
        Write-Host "Removing $(if ($curr.URL) { $curr.URL } else { $curr.Name })..."
        Remove-Item $_.FullName
        if(Test-Path "$cachedir\$($curr.Name).txt") {
            Remove-Item "$cachedir\$($curr.Name).txt"
        }
    }

    Write-Host "Deleted: $($files.length) $(pluralize $files.length 'file' 'files'), $(filesize $total_length)" -ForegroundColor Yellow
}

switch($cmd) {
    {$_ -in $null, 'show'}  { cacheshow   $args }
    {$_ -in 'rm', 'remove'} { cacheremove $args }
    default                 { my_usage }
}

exit 0
