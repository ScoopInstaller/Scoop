# Summary: Setup scoop shim and main bucket as does the Scoop installer

. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\download.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\system.ps1"

Write-Host 'Creating scoop shim...'
shim "$(currentdir 'scoop')\bin\scoop.ps1" $false

Write-Host 'Seeding main bucket...'
$MainBucketPath = ensure (Find-BucketDirectory -Name 'main' -Root)
$MainBucketArchive = Join-Path $MainBucketPath "scoop-main.zip"
Start-Download 'https://github.com/ScoopInstaller/Main/archive/refs/heads/master.zip' $MainBucketArchive
Expand-ZipArchive -Path $MainBucketArchive -DestinationPath $MainBucketPath -ExtractDir "Main-master" -Removal
set_config 'last_update' ([System.DateTime]::Now.ToString('o')) | Out-Null
