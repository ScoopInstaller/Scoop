#Requires -Version 5.1
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host 'Check and install testsuite dependencies ...'
if (Get-InstalledModule -Name Pester -MinimumVersion 5.2 -MaximumVersion 5.99 -ErrorAction SilentlyContinue) {
    Write-Host 'Pester 5 is already installed.'
} else {
    Write-Host 'Installing Pester 5 ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -MinimumVersion 5.2 -MaximumVersion 5.99 -SkipPublisherCheck
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
