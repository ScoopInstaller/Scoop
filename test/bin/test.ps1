#Requires -Version 5.0
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '4.10.1' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }
param(
    [String] $TestPath = 'test/'
)

$splat = @{
    Path     = $TestPath
    PassThru = $true
}

$excludes = @()
if ($env:CI -eq $true) {
    $resultsXml = "$PSScriptRoot/TestResults.xml"

    $splat += @{
        OutputFile   = $resultsXml
        OutputFormat = 'NUnitXML'
    }

    $commit = if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT) { $env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT } else { $env:APPVEYOR_REPO_COMMIT }
    $commitMessage = "$env:APPVEYOR_REPO_COMMIT_MESSAGE $env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED".TrimEnd()

    if ($commitMessage -match '!linter') {
        Write-Warning "Skipping code linting per commit flag '!linter'"
        $excludes += 'Linter'
    }

    $changed_scripts = (Get-GitChangedFile -Include '*.ps1' -Commit $commit)
    if (!$changed_scripts) {
        Write-Warning "Skipping tests and code linting for *.ps1 files because they didn't change"
        $excludes += 'Linter'
        $excludes += 'Scoop'
    }

    if (!($changed_scripts -like '*decompress.ps1')) {
        Write-Warning "Skipping tests and code linting for decompress.ps1 files because it didn't change"
        $excludes += 'Decompress'
    }

    if ($env:CI_WINDOWS -ne $true) {
        Write-Warning 'Skipping tests and code linting for decompress.ps1 because they only work on Windows'
        $excludes += 'Decompress'
    }

    if ($commitMessage -match '!manifests') {
        Write-Warning "Skipping manifest validation per commit flag '!manifests'"
        $excludes += 'Manifests'
    }

    $changed_manifests = (Get-GitChangedFile -Include 'bucket\*.json' -Commit $commit)
    if (!$changed_manifests) {
        Write-Warning "Skipping tests and validation for manifest files because they didn't change"
        $excludes += 'Manifests'
    }

    if ($env:CI_WINDOWS -eq $true -and 'Decompress' -notin $excludes) {
        Write-Host 'Install decompress dependencies ...'

        $env:SCOOP_HELPERS = 'C:\projects\helpers'
        if (!(Test-Path $env:SCOOP_HELPERS)) {
            New-Item -ItemType Directory -Path $env:SCOOP_HELPERS
        }
        if (!(Test-Path "$env:SCOOP_HELPERS\lessmsi\lessmsi.exe")) {
            Start-FileDownload 'https://github.com/activescott/lessmsi/releases/download/v1.10.0/lessmsi-v1.10.0.zip' -FileName "$env:SCOOP_HELPERS\lessmsi.zip"
            & 7z.exe x "$env:SCOOP_HELPERS\lessmsi.zip" -o"$env:SCOOP_HELPERS\lessmsi" -y
            $env:LESSMSI = "$env:SCOOP_HELPERS\lessmsi\lessmsi.exe"
        }
        if (!(Test-Path "$env:SCOOP_HELPERS\innounp\innounp.exe")) {
            Start-FileDownload 'https://raw.githubusercontent.com/ScoopInstaller/Binary/master/innounp/innounp050.rar' -FileName "$env:SCOOP_HELPERS\innounp.rar"
            & 7z.exe x "$env:SCOOP_HELPERS\innounp.rar" -o"$env:SCOOP_HELPERS\innounp" -y
            $env:INNOUNP = "$env:SCOOP_HELPERS\innounp\innounp.exe"
        }
        if (!(Test-Path "$env:SCOOP_HELPERS\zstd\zstd.exe")) {
            Start-FileDownload 'https://github.com/facebook/zstd/releases/download/v1.5.1/zstd-v1.5.1-win32.zip' -FileName "$env:SCOOP_HELPERS\zstd.zip"
            & 7z.exe x "$env:SCOOP_HELPERS\zstd.zip" -o"$env:SCOOP_HELPERS\zstd" -y
            $env:ZSTD = "$env:SCOOP_HELPERS\zstd\zstd.exe"
        }
    }
}

if (!(Test-Path "$PSScriptRoot\..\..\bucket")) {
    Write-Warning 'Skipping tests and validation for manifest files because there is no bucket'
    $excludes += 'Manifests'
}

if ($excludes.Length -gt 0) {
    $splat.ExcludeTag = $excludes
}

Write-Host 'Invoke-Pester' @splat
$result = Invoke-Pester @splat

if ($env:CI -eq $true) {
    (New-Object Net.WebClient).UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $resultsXml)
}

if ($result.FailedCount -gt 0) {
    exit $result.FailedCount
}
