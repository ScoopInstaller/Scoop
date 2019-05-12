#requires -Version 5.0
#requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '4.4.0' }
#requires -Modules @{ ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.17.1' }
param(
    [String] $TestPath = 'test/'
)

$resultsXml = "$PSScriptRoot/TestResults.xml"
$excludes = @()

$splat = @{
    Path         = $TestPath
    OutputFile   = $resultsXml
    OutputFormat = 'NUnitXML'
    PassThru     = $true
}

if ($env:CI -eq $true) {
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

    $changed_scripts = (Get-GitChangedFile -Include '*decompress.ps1' -Commit $commit)
    if (!$changed_scripts) {
        Write-Warning "Skipping tests and code linting for decompress.ps1 files because it didn't change"
        $excludes += 'Decompress'
    }

    if ($env:CI_WINDOWS -ne $true) {
        Write-Warning "Skipping tests and code linting for decompress.ps1 because they only work on Windows"
        $excludes += 'Decompress'
    }

    if ($commitMessage -match '!manifests') {
        Write-Warning "Skipping manifest validation per commit flag '!manifests'"
        $excludes += 'Manifests'
    }

    $changed_manifests = (Get-GitChangedFile -Include '*.json' -Commit $commit)
    if (!$changed_manifests) {
        Write-Warning "Skipping tests and validation for manifest files because they didn't change"
        $excludes += 'Manifests'
    }

    if ($excludes.Length -gt 0) {
        $splat.ExcludeTag = $excludes
    }
}

Write-Host 'Invoke-Pester' @splat
$result = Invoke-Pester @splat

(New-Object Net.WebClient).UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $resultsXml)

if ($result.FailedCount -gt 0) {
    exit $result.FailedCount
}
