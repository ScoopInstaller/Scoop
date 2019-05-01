<#
.SYNOPSIS
    Update supporting tools to the latest version.
.PARAMETER Supporting
    Name of supporting tool to be updated.
#>
param([String] $Supporting = '*')

. "$PSScriptRoot\..\lib\config.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\install.ps1"

$Sups = (Get-ChildItem "$PSScriptRoot\..\supporting\*" -File -Include "$Supporting.json").FullName

foreach ($sup in $Sups) {
    $name = ((Split-Path $sup -Leaf) -split '\.')[0]
    $folder = Split-Path $sup -Parent
    $dir = "$folder\$name\bin"

    Write-Host "Updating $name" -ForegroundColor Magenta

    Invoke-Expression "$PSScriptRoot\checkver.ps1 -App $name -Dir $folder -Update"
    $manifest = parse_json $sup
    if (!(Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null }

    $fname = dl_urls $name $manifest.version $manifest '' default_architecture $dir $true $true
    # Pre install is enough now
    pre_install $manifest $architecture

    Write-Host "$name done" -ForegroundColor Green
}
