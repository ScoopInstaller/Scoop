#Requires -Version 5.1
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
Write-Output 'Check and install testsuite dependencies ...'
if (Get-InstalledModule -Name Pester -MinimumVersion 6.0 -MaximumVersion 6.99 -ErrorAction SilentlyContinue) {
    Write-Output 'Pester 6 is already installed.'
} else {
    Write-Output 'Installing Pester 6 ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -MinimumVersion 6.0 -MaximumVersion 6.99 -SkipPublisherCheck
}
if (Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion 1.17 -ErrorAction SilentlyContinue) {
    Write-Output 'PSScriptAnalyzer is already installed.'
} else {
    Write-Output 'Installing PSScriptAnalyzer ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name PSScriptAnalyzer -SkipPublisherCheck
}
if (Get-InstalledModule -Name BuildHelpers -MinimumVersion 2.0 -ErrorAction SilentlyContinue) {
    Write-Output 'BuildHelpers is already installed.'
} else {
    Write-Output 'Installing BuildHelpers ...'
    Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name BuildHelpers -SkipPublisherCheck
}
