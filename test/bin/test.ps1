#Requires -Version 5.0
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.16' }
#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '4.10.1' }
#Requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }
param(
    [String] $TestPath = 'test/'
)

$splat = @{
    Path     = $TestPath
    PassThru = $true
}

if ($env:CI -eq $true) {
    $resultsXml = "$PSScriptRoot/TestResults.xml"
    $excludes = @()

    $splat += @{
        OutputFile   = $resultsXml
        OutputFormat = 'NUnitXML'
    }

    $commit = $env:BHCommitHash
    $commitMessage = $env:BHCommitMessage

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

    $changed_scripts = (Get-GitChangedFile -Include '*decompress.ps1' -Commit $commit)
    if (!$changed_scripts) {
        Write-Warning "Skipping tests and code linting for decompress.ps1 files because it didn't change"
        $excludes += 'Decompress'
    }

    if ($env:RUNNER_OS -ne 'Windows') {
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
exit $result.FailedCount
