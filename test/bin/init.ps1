Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

Write-Host "Install dependencies ..."
Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -SkipPublisherCheck
Install-Module -Repository PSGallery -Scope CurrentUser -Name PSScriptAnalyzer,BuildHelpers

if($env:CI -eq $true) {
    Write-Host "Load 'BuildHelpers' environment variables ..."
    Set-BuildEnvironment -Force
}

$buildVariables = ( Get-ChildItem -Path 'Env:' ).Where( { $_.Name -match "^(?:BH|CI(?:_|$)|APPVEYOR)" } )
$buildVariables += ( Get-Variable -Name 'CI_*' -Scope 'Script' )
$details = $buildVariables |
    Where-Object -FilterScript { $_.Name -notmatch 'EMAIL' } |
    Sort-Object -Property 'Name' |
    Format-Table -AutoSize -Property 'Name', 'Value' |
    Out-String
Write-Host "CI variables:"
Write-Host $details -ForegroundColor DarkGray
