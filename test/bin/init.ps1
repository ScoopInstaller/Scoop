#Requires -Version 5.0
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host (7z.exe | Select-String -Pattern '7-Zip').ToString()
Write-Host 'Install testsuite dependencies ...'
Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -RequiredVersion 4.10.1 -SkipPublisherCheck
Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name PSScriptAnalyzer, BuildHelpers
