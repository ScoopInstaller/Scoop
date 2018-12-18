<#
.SYNOPSIS
    Search description on manifests homepage.
.PARAMETER App
    Manifest name to search.
    Placeholders are supported.
.PARAMETER Dir
    Where to search for manifest(s).
#>
param(
    [String] $App = '*',
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        }
        $true
    })]
    # TODO: YAML seelct correct folder
    # [String] $Dir = "$PSScriptRoot\..\bucket",
    [String] $Dir = "$psscriptroot\..\bucket\yamTEST"
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\description.ps1"

$Dir = Resolve-Path $Dir
$Queue = @()

Get-ChildItem $Dir "$App.*" | ForEach-Object {
    $man = Scoop-ParseManifest "$Dir\$($_.Name)"
    $Queue += , @($_.Name, $man)
}

$Queue | ForEach-Object {
    $app, $man = $_
    Write-Host "$app`: " -NoNewLine

    if(!$man.homepage) {
        Write-Host "`nNo homepage set." -ForegroundColor Red
        return
    }
    # get description from homepage
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.DownloadString($man.homepage)
    } catch {
        Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $description, $descr_method = find_description $man.homepage $home_html
    if(!$description) {
        Write-Host "`nDescription not found ($($man.homepage))" -ForegroundColor Red
        return
    }

    $description = clean_description $description

    Write-Host "(found by $descr_method)"
    Write-Host "  ""$description""" -ForegroundColor Green
}

