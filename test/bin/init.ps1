#Requires -Version 5.1
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host (7z.exe | Select-String -Pattern '7-Zip').ToString()
Write-Host 'Check and install testsuite dependencies ...'
if (Get-InstalledModule -Name Pester -MinimumVersion 4.0 -MaximumVersion 4.99 -ErrorAction SilentlyContinue) {
    Write-Host 'Pester 4 is already installed.'
} else {
    Write-Host 'Installing Pester 4 ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -MinimumVersion 4.0 -MaximumVersion 4.99 -SkipPublisherCheck
}
if (Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion 1.17 -ErrorAction SilentlyContinue) {
    Write-Host 'PSScriptAnalyzer is already installed.'
} else {
    Write-Host 'Installing PSScriptAnalyzer ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name PSScriptAnalyzer -SkipPublisherCheck
}
if (Get-InstalledModule -Name BuildHelpers -MinimumVersion 2.0 -ErrorAction SilentlyContinue) {
    Write-Host 'BuildHelpers is already installed.'
} else {
    Write-Host 'Installing BuildHelpers ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name BuildHelpers -SkipPublisherCheck
}
