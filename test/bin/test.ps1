#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; MaximumVersion = '4.99' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }
param(
    [String] $TestPath = $(Resolve-Path "$PSScriptRoot\..\")
)

$splat = @{
    Path     = $TestPath
    PassThru = $true
}

if ($env:CI -eq $true) {
    Write-Host "Load 'BuildHelpers' environment variables ..."
    Set-BuildEnvironment -Force
    $CI_WIN = (($env:RUNNER_OS -eq 'Windows') -or ($env:CI_WINDOWS -eq $true))

    $excludes = @()
    $commit = $env:BHCommitHash
    $commitMessage = $env:BHCommitMessage

    # Check if tests are called from the Core itself, if so, adding excludes
    if ($TestPath -eq $(Resolve-Path "$PSScriptRoot\..\")) {
        if ($commitMessage -match '!linter') {
            Write-Warning "Skipping code linting per commit flag '!linter'"
            $excludes += 'Linter'
        }

        if (!$CI_WIN) {
            Write-Warning 'Skipping tests and code linting for decompress.ps1 because they only work on Windows'
            $excludes += 'Decompress'
        }

        $changedScripts = (Get-GitChangedFile -Include '*.ps1' -Commit $commit)
        if (!$changedScripts) {
            Write-Warning "Skipping tests and code linting for *.ps1 files because they didn't change"
            $excludes += 'Linter'
            $excludes += 'Scoop'
        }

        if (!($changedScripts -like '*decompress.ps1') -and !($changedScripts -like '*Decompress.Tests.ps1')) {
            Write-Warning "Skipping tests and code linting for decompress.ps1 files because it didn't change"
            $excludes += 'Decompress'
        }

        if ('Decompress' -notin $excludes) {
            Write-Host 'Install decompress dependencies ...'

            $env:SCOOP_HELPERS_PATH = 'C:\projects\helpers'
            if (!(Test-Path $env:SCOOP_HELPERS_PATH)) {
                New-Item -ItemType Directory -Path $env:SCOOP_HELPERS_PATH
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

    if ($excludes.Length -gt 0) {
        $splat.ExcludeTag = $excludes
    }

    # Display CI environment variables
    $buildVariables = ( Get-ChildItem -Path 'Env:' ).Where( { $_.Name -match '^(?:BH|CI(?:_|$)|APPVEYOR|GITHUB_|RUNNER_|SCOOP_)' } )
    $buildVariables += ( Get-Variable -Name 'CI_*' -Scope 'Script' )
    $details = $buildVariables |
        Where-Object -FilterScript { $_.Name -notmatch 'EMAIL' } |
        Sort-Object -Property 'Name' |
        Format-Table -AutoSize -Property 'Name', 'Value' |
        Out-String
    Write-Host 'CI variables:'
    Write-Host $details -ForegroundColor DarkGray

    # AppVeyor
    if ($env:BHBuildSystem -eq "AppVeyor") {
        $resultsXml = "$PSScriptRoot\TestResults.xml"
        $splat += @{
            OutputFile   = $resultsXml
            OutputFormat = 'NUnitXML'
        }

        Write-Host 'Invoke-Pester' @splat
        $result = Invoke-Pester @splat

        (New-Object Net.WebClient).UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $resultsXml)
        exit $result.FailedCount
    }
}

# GitHub Actions / Local
Write-Host 'Invoke-Pester' @splat
$result = Invoke-Pester @splat
exit $result.FailedCount
