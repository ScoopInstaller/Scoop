. "$psscriptroot\..\lib\autoupdate.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\config.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"

$SUPPORTINGS = Resolve-Path (Get-ChildItem "$PSScriptRoot\..\supporting\*" -File -Include '*.json').FullName

foreach ($sup in $SUPPORTINGS) {
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
