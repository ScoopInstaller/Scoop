<#
.SYNOPSIS
    Search for application description on homepage.
.PARAMETER App
    Manifest name to search.
    Placeholders are supported.
.PARAMETER Dir
    Where to search for manifest(s).
#>
param(
    [String] $App = '*',
    [Parameter(Mandatory = $true)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [String] $Dir
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\description.ps1"

$Dir = Resolve-Path $Dir
$Queue = @()

Get-ChildItem $Dir "$App.json" | ForEach-Object {
    $manifest = parse_json "$Dir\$($_.Name)"
    $Queue += , @(($_.Name -replace '\.json$', ''), $manifest)
}

$Queue | ForEach-Object {
    $name, $manifest = $_
    Write-Host "$name`: " -NoNewline

    if (!$manifest.homepage) {
        Write-Host "`nNo homepage set." -ForegroundColor Red
        return
    }
    # get description from homepage
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.DownloadString($manifest.homepage)
    } catch {
        Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $description, $descr_method = find_description $manifest.homepage $home_html
    if (!$description) {
        Write-Host "`nDescription not found ($($manifest.homepage))" -ForegroundColor Red
        return
    }

    $description = clean_description $description

    Write-Host "(found by $descr_method)"
    Write-Host "  ""$description""" -ForegroundColor Green
}
