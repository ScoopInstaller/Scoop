#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }
param(
    [String] $TestPath = (Convert-Path "$PSScriptRoot\..")
)

$pesterConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path     = $TestPath
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
}
$excludes = @()

if ($IsLinux -or $IsMacOS) {
    Write-Warning 'Skipping Windows-only tests on Linux/macOS'
    $excludes += 'Windows'
}

if ($env:CI -eq $true) {
    Write-Host "Load 'BuildHelpers' environment variables ..."
    Set-BuildEnvironment -Force

    # Check if tests are called from the Core itself, if so, adding excludes
    if ($TestPath -eq (Convert-Path "$PSScriptRoot\..")) {
        if ($env:BHCommitMessage -match '!linter') {
            Write-Warning "Skipping code linting per commit flag '!linter'"
            $excludes += 'Linter'
        }

        $changedScripts = (Get-GitChangedFile -Include '*.ps1', '*.psd1', '*.psm1' -Commit $env:BHCommitHash)
        if (!$changedScripts) {
            Write-Warning "Skipping tests and code linting for PowerShell scripts because they didn't change"
            $excludes += 'Linter'
            $excludes += 'Scoop'
        }

        if (!($changedScripts -like '*decompress.ps1') -and !($changedScripts -like '*Decompress.Tests.ps1')) {
            Write-Warning "Skipping tests and code linting for decompress.ps1 files because it didn't change"
            $excludes += 'Decompress'
        }

        if ('Decompress' -notin $excludes -and 'Windows' -notin $excludes) {
            Write-Host 'Install decompress dependencies ...'

            Write-Host (7z.exe | Select-String -Pattern '7-Zip').ToString()

            $env:SCOOP_HELPERS_PATH = 'C:\projects\helpers'
            if (!(Test-Path $env:SCOOP_HELPERS_PATH)) {
                New-Item -ItemType Directory -Path $env:SCOOP_HELPERS_PATH | Out-Null
            }

            $env:SCOOP_LESSMSI_PATH = "$env:SCOOP_HELPERS_PATH\lessmsi\lessmsi.exe"
            if (!(Test-Path $env:SCOOP_LESSMSI_PATH)) {
                $source = 'https://github.com/activescott/lessmsi/releases/download/v1.10.0/lessmsi-v1.10.0.zip'
                $destination = "$env:SCOOP_HELPERS_PATH\lessmsi.zip"
                Invoke-WebRequest -Uri $source -OutFile $destination
                & 7z.exe x "$env:SCOOP_HELPERS_PATH\lessmsi.zip" -o"$env:SCOOP_HELPERS_PATH\lessmsi" -y | Out-Null
            }

            $env:SCOOP_INNOUNP_PATH = "$env:SCOOP_HELPERS_PATH\innounp\innounp.exe"
            if (!(Test-Path $env:SCOOP_INNOUNP_PATH)) {
                $source = 'https://raw.githubusercontent.com/ScoopInstaller/Binary/master/innounp/innounp050.rar'
                $destination = "$env:SCOOP_HELPERS_PATH\innounp.rar"
                Invoke-WebRequest -Uri $source -OutFile $destination
                & 7z.exe x "$env:SCOOP_HELPERS_PATH\innounp.rar" -o"$env:SCOOP_HELPERS_PATH\innounp" -y | Out-Null
            }

            # Only download zstd for AppVeyor, GitHub Actions has zstd installed by default
            if ($env:BHBuildSystem -eq 'AppVeyor') {
                $env:SCOOP_ZSTD_PATH = "$env:SCOOP_HELPERS_PATH\zstd\zstd.exe"
                if (!(Test-Path $env:SCOOP_ZSTD_PATH)) {
                    $source = 'https://github.com/facebook/zstd/releases/download/v1.5.1/zstd-v1.5.1-win32.zip'
                    $destination = "$env:SCOOP_HELPERS_PATH\zstd.zip"
                    Invoke-WebRequest -Uri $source -OutFile $destination
                    & 7z.exe x "$env:SCOOP_HELPERS_PATH\zstd.zip" -o"$env:SCOOP_HELPERS_PATH\zstd" -y | Out-Null
                }
            } else {
                $env:SCOOP_ZSTD_PATH = (Get-Command zstd.exe).Path
            }
        }
    }

    # Display CI environment variables
    $buildVariables = (Get-ChildItem -Path 'Env:').Where({ $_.Name -match '^(?:BH|CI(?:_|$)|APPVEYOR|GITHUB_|RUNNER_|SCOOP_)' })
    $details = $buildVariables |
        Where-Object -FilterScript { $_.Name -notmatch 'EMAIL' } |
        Sort-Object -Property 'Name' |
        Format-Table -AutoSize -Property 'Name', 'Value' |
        Out-String
    Write-Host 'CI variables:'
    Write-Host $details -ForegroundColor DarkGray
}

if ($excludes.Length -gt 0) {
    $pesterConfig.Filter.ExcludeTag = $excludes
}

if ($env:BHBuildSystem -eq 'AppVeyor') {
    # AppVeyor
    $resultsXml = "$PSScriptRoot\TestResults.xml"
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = $resultsXml
    $result = Invoke-Pester -Configuration $pesterConfig
    Add-TestResultToAppveyor -TestFile $resultsXml
} else {
    # GitHub Actions / Local
    $result = Invoke-Pester -Configuration $pesterConfig
}

exit $result.FailedCount
