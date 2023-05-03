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
    [String] $App = '*',
    [Parameter(Mandatory = $true)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [String] $Dir,
    [Switch] $SkipSupported
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

$Dir = Convert-Path $Dir

Write-Host '[' -NoNewLine
Write-Host 'C' -NoNewLine -ForegroundColor Green
Write-Host ']heckver'
Write-Host ' | [' -NoNewLine
Write-Host 'A' -NoNewLine -ForegroundColor Cyan
Write-Host ']utoupdate'
Write-Host ' |  |'

Get-ChildItem $Dir -Filter "$App.json" -Recurse | ForEach-Object {
    $json = parse_json $_.FullName

    if ($SkipSupported -and $json.checkver -and $json.autoupdate) { return }

    Write-Host '[' -NoNewLine
    Write-Host $(if ($json.checkver) { 'C' } else { ' ' }) -NoNewLine -ForegroundColor Green
    Write-Host ']' -NoNewLine

    Write-Host '[' -NoNewLine
    Write-Host $(if ($json.autoupdate) { 'A' } else { ' ' }) -NoNewLine -ForegroundColor Cyan
    Write-Host '] ' -NoNewLine
    Write-Host $_.BaseName
}
