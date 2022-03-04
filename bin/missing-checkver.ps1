<#
.SYNOPSIS
    Check if manifest contains checkver and autoupdate property.
.PARAMETER App
    Manifest name.
    Wirldcard is supported.
.PARAMETER Dir
    Location of manifests.
.PARAMETER SkipSupported
    Manifests with checkver and autoupdate will not be presented.
#>
param(
    [string] $App = '*',
    [Parameter(Mandatory = $true)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [string] $Dir,
    [switch] $SkipSupported
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

$Dir = Resolve-Path $Dir

Write-Host '[' -NoNewline
Write-Host 'C' -NoNewline -ForegroundColor Green
Write-Host ']heckver'
Write-Host ' | [' -NoNewline
Write-Host 'A' -NoNewline -ForegroundColor Cyan
Write-Host ']utoupdate'
Write-Host ' |  |'

Get-ChildItem $Dir "$App.json" | ForEach-Object {
    $json = parse_json "$Dir\$($_.Name)"

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -NoNewline -ForegroundColor Green
    Write-Host ']' -NoNewline

    Write-Host '[' -NoNewline
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -NoNewline -ForegroundColor Cyan
    Write-Host '] ' -NoNewline
    Write-Host (strip_ext $_.Name)
}
