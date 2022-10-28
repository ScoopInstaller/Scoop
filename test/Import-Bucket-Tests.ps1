#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }
param(
    [String] $BucketPath = $MyInvocation.PSScriptRoot
)

. "$PSScriptRoot\Scoop-00File.Tests.ps1" -TestPath $BucketPath

Describe 'Manifest validates against the schema' {
    BeforeDiscovery {
        $bucketDir = if (Test-Path "$BucketPath\bucket") {
            "$BucketPath\bucket"
        } else {
            $BucketPath
        }
        if ($env:CI -eq $true) {
            Set-BuildEnvironment -Force
            $changedManifests = @(Get-GitChangedFile -Path $bucketDir -Include '*.json' -Commit $env:BHCommitHash)
        }
        $manifestFiles = (Get-ChildItem $bucketDir -Filter '*.json' -Recurse).FullName
        if ($changedManifests) {
            $manifestFiles = $manifestFiles | Where-Object { $_ -in $changedManifests }
        }
    }
    BeforeAll {
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
        # Could not use backslash '\' in Linux/macOS for .NET object 'Scoop.Validator'
        $validator = New-Object Scoop.Validator("$PSScriptRoot/../schema.json", $true)
        $global:quotaExceeded = $false
    }
    It '<_>' -TestCases $manifestFiles {
        if ($global:quotaExceeded) {
            Set-ItResult -Skipped -Because 'Schema validation limit exceeded.'
        } else {
            $file = $_ # exception handling may overwrite $_
            try {
                $validator.Validate($file)
                if ($validator.Errors.Count -gt 0) {
                    Write-Host "  [-] $_ has $($validator.Errors.Count) Error$(If($validator.Errors.Count -gt 1) { 's' })!" -ForegroundColor Red
                    Write-Host $validator.ErrorsAsString -ForegroundColor Yellow
                }
                $validator.Errors.Count | Should -Be 0
            } catch {
                if ($_.Exception.Message -like '*The free-quota limit of 1000 schema validations per hour has been reached.*') {
                    $global:quotaExceeded = $true
                    Set-ItResult -Skipped -Because 'Schema validation limit exceeded.'
                } else {
                    throw
                }
            }
        }
    }
}
