param($bucketdir = "$PSScriptRoot\..\bucket")
. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Manifest Validator' -Tag 'Validator' {
    BeforeAll {
        $working_dir = setup_working 'manifest'
        $schema = "$PSScriptRoot/../schema.json"
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
            $validator = New-Object Scoop.Validator("$working_dir/broken_schema.json", $true)
            $validator.Validate("$working_dir/wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_schema.*(line 6).*(position 4)'
        }
        It 'fails with broken manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir/broken_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 1
            $validator.Errors | Select-Object -First 1 | Should -Match 'broken_wget.*(line 5).*(position 4)'
        }
        It 'fails with invalid manifest' {
            $validator = New-Object Scoop.Validator($schema, $true)
            $validator.Validate("$working_dir/invalid_wget.json") | Should -BeFalse
            $validator.Errors.Count | Should -Be 16
            $validator.Errors | Select-Object -First 1 | Should -Match "Property 'randomproperty' has not been defined and the schema does not allow additional properties\."
            $validator.Errors | Select-Object -Last 1 | Should -Match 'Required properties are missing from object: version, description\.'
        }
    }
}

Describe 'manifest validates against the schema' -Tag 'Manifests' {
    BeforeAll {
        $changed_manifests = @()
        if ($env:CI -eq $true) {
            $commit = if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT) { $env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT } else { $env:APPVEYOR_REPO_COMMIT }
            $changed_manifests = (Get-GitChangedFile -Include 'bucket\*.json' -Commit $commit)
        }
        $manifest_files = Get-ChildItem $bucketdir *.json
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
