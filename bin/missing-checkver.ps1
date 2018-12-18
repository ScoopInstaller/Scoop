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
    # [String] $Dir = "$PSScriptRoot\..\bucket",
    # TODO: YAML select correct dir
    [String] $Dir = "$PSScriptRoot\..\bucket\yamTEST",
    [Switch] $SkipSupported
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

$Dir = Resolve-Path $Dir

Write-Host '[' -NoNewLine
Write-Host 'C' -NoNewLine -ForegroundColor Green
Write-Host ']heckver'
Write-Host ' | [' -NoNewLine
Write-Host 'A' -NoNewLine -ForegroundColor Cyan
Write-Host ']utoupdate'
Write-Host ' |  |'

Get-ChildItem $Dir "$App.*" | ForEach-Object {
    $man = Scoop-ParseManifest "$Dir\$($_.Name)"

    if ($SkipSupported -and $man.checkver -and $man.autoupdate) { return }

    Write-Host '[' -NoNewLine
    Write-Host $(if ($man.checkver) { 'C' } else { ' ' }) -NoNewLine -ForegroundColor Green
    Write-Host ']' -NoNewLine

    Write-Host '[' -NoNewLine
    Write-Host $(if ($man.autoupdate) { 'A' } else { ' ' }) -NoNewLine -ForegroundColor Cyan
    Write-Host '] ' -NoNewLine
    Write-Host (strip_ext $_.Name)
}
