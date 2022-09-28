#Requires -Version 5.0
#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '4.10.1' }
param(
    [ValidateNotNullOrEmpty()]
    [String]
    $repo_dir = (Split-Path -Path $MyInvocation.PSCommandPath -Parent)
)

. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\unix.ps1"

$bucketdir = $repo_dir
if (Test-Path("$repo_dir\..\bucket")) {
    $bucketdir = "$repo_dir\..\bucket"
} elseif (Test-Path("$repo_dir\bucket")) {
    $bucketdir = "$repo_dir\bucket"
}

# Tests for non manifest files
$repo_files = @(Get-ChildItem -Path $repo_dir -File -Recurse)
$project_file_exclusions = @(
    '[\\/]\.git[\\/]',
    '.sublime-workspace$',
    '.DS_Store$'
)
. "$PSScriptRoot\Import-File-Tests.ps1"

# Tests for manifest files
Describe 'Manifest Validator' -Tag 'Validator' {
    BeforeAll {
        $schema = "$PSScriptRoot\..\schema.json"
        $working_dir = setup_working 'manifest'
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Newtonsoft.Json.dll"
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Newtonsoft.Json.Schema.dll"
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
    }

    It 'Scoop.Validator is available' {
        ([System.Management.Automation.PSTypeName]'Scoop.Validator').Type | Should -Be 'Scoop.Validator'
    }

    Context 'parse_json function' {
        It 'fails with invalid json' {
            { parse_json "$working_dir\broken_wget.json" } | Should -Throw
        }
    }

    Context 'schema validation' {
        It 'fails with broken schema' {
            $validator = New-Object Scoop.Validator("$working_dir\broken_schema.json", $true)
            $validator.Validate("$working_dir\wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_schema.*(line 6).*(position 4)'
        }
        It 'fails with broken manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir\broken_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_wget.*(line 5).*(position 4)'
        }
        It 'fails with invalid manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir\invalid_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 16
            $validator.Errors | Select-Object -First 1 | Should -Match "Property 'randomproperty' has not been defined and the schema does not allow additional properties\."
            $validator.Errors | Select-Object -Last 1 | Should -Match 'Required properties are missing from object: version\.'
        }
    }
}
Describe 'manifest validates against the schema' -Tag 'Manifests' {
    BeforeAll {
        $schema = "$PSScriptRoot\..\schema.json"
        $changed_manifests = @()
        if ($env:CI -eq $true) {
            # AppVeyor
            $commit = if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT) { $env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT } else { $env:APPVEYOR_REPO_COMMIT }

            # GitHub Actions
            if ($env:GITHUB_SHA) {
                $commit = $env:GITHUB_SHA
            }
            $changed_manifests = (Get-GitChangedFile -Path $repo_dir -Include '*.json' -Commit $commit)
        }
        $manifest_files = Get-ChildItem $bucketdir -Filter '*.json' -Recurse
        $validator = New-Object Scoop.Validator($schema, $true)
    }

    $quota_exceeded = $false

    $manifest_files | ForEach-Object {
        $skip_manifest = ($changed_manifests -inotcontains $_.FullName)
        if ($env:CI -ne $true -or $changed_manifests -imatch 'schema.json') {
            $skip_manifest = $false
        }
        It "$_" -Skip:$skip_manifest {
            $file = $_ # exception handling may overwrite $_

            if (!($quota_exceeded)) {
                try {
                    $validator.Validate($file.fullname)

                    if ($validator.Errors.Count -gt 0) {
                        Write-Host -f red "      [-] $_ has $($validator.Errors.Count) Error$(If($validator.Errors.Count -gt 1) { 's' })!"
                        Write-Host -f yellow $validator.ErrorsAsString
                    }
                    $validator.Errors.Count | Should -Be 0
                } catch {
                    if ($_.exception.message -like '*The free-quota limit of 1000 schema validations per hour has been reached.*') {
                        $quota_exceeded = $true
                        Write-Host -f darkyellow 'Schema validation limit exceeded. Will skip further validations.'
                    } else {
                        throw
                    }
                }
            }

            $manifest = parse_json $file.fullname
            $url = arch_specific 'url' $manifest '32bit'
            $url64 = arch_specific 'url' $manifest '64bit'
            if (!$url) {
                $url = $url64
            }
            $url | Should -Not -BeNullOrEmpty
        }
    }
}
