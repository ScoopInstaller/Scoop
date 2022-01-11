Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
(7z.exe | Select-String -Pattern '7-Zip').ToString()
Write-Host 'Install dependencies ...'
Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name Pester -RequiredVersion 4.10.1 -SkipPublisherCheck
Install-Module -Repository PSGallery -Scope CurrentUser -Force -Name PSScriptAnalyzer, BuildHelpers

if ($env:CI -eq $true) {
    if ($env:RUNNER_OS -eq 'Windows') {
        Write-Host 'Setup helpers ...'
        # Do not force maintainers to have this inside environment appveyor config
        if (-not $env:SCOOP_HELPERS) {
            $env:SCOOP_HELPERS = 'C:\projects\helpers'
            [System.Environment]::SetEnvironmentVariable('SCOOP_HELPERS', $env:SCOOP_HELPERS, 'Machine')
        }

        if (!(Test-Path $env:SCOOP_HELPERS)) {
            New-Item -ItemType Directory -Path $env:SCOOP_HELPERS
        }
        if (!(Test-Path "$env:SCOOP_HELPERS\lessmsi\lessmsi.exe")) {
            $source = 'https://github.com/activescott/lessmsi/releases/download/v1.10.0/lessmsi-v1.10.0.zip'
            $destination = "$env:SCOOP_HELPERS\lessmsi.zip"
            Invoke-WebRequest -Uri $source -OutFile $destination
            & 7z.exe x "$destination" -o"$env:SCOOP_HELPERS\lessmsi" -y
        }
        if (!(Test-Path "$env:SCOOP_HELPERS\innounp\innounp.exe")) {
            $source = 'https://raw.githubusercontent.com/ScoopInstaller/Binary/master/innounp/innounp050.rar'
            $destination = "$env:SCOOP_HELPERS\innounp.rar"
            Invoke-WebRequest -Uri $source -OutFile $destination
            & 7z.exe x "$destination" -o"$env:SCOOP_HELPERS\innounp" -y
        }
    }

    Write-Host "Load 'BuildHelpers' environment variables ..."
    Set-BuildEnvironment -Force
}

$buildVariables = ( Get-ChildItem -Path 'Env:' ).Where( { $_.Name -match '^(?:BH|CI(?:_|$)|APPVEYOR)' } )
$buildVariables += ( Get-Variable -Name 'CI_*' -Scope 'Script' )
$details = $buildVariables |
    Where-Object -FilterScript { $_.Name -notmatch 'EMAIL' } |
    Sort-Object -Property 'Name' |
    Format-Table -AutoSize -Property 'Name', 'Value' |
    Out-String
Write-Host 'CI variables:'
Write-Host $details -ForegroundColor DarkGray
