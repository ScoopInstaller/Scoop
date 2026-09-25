BeforeAll {
    . "$PSScriptRoot\..\lib\json.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
}

Describe 'JSON parse and beautify' -Tag 'Scoop' {
    Context 'Parse JSON' {
        It 'success with valid json' {
            { parse_json "$PSScriptRoot\fixtures\manifest\wget.json" } | Should -Not -Throw
        }
        It 'fails with invalid json' {
            { parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json" } | Should -Throw
        }
    }
    Context 'Beautify JSON' {
        BeforeDiscovery {
            $manifests = (Get-ChildItem "$PSScriptRoot\fixtures\format\formatted" -File -Filter '*.json').Name
        }
        BeforeAll {
            $format = "$PSScriptRoot\fixtures\format"
        }
        It '<_>' -ForEach $manifests {
            $pretty_json = (parse_json "$format\unformatted\$_") | ConvertToPrettyJson
            $correct = (Get-Content "$format\formatted\$_") -join "`r`n"
            $correct.CompareTo($pretty_json) | Should -Be 0
        }
    }
}

Describe 'Handle ARM64 and correctly fallback' -Tag 'Scoop' {
    It 'Should return "arm64" if supported' {
        $manifest1 = @{ url = 'test'; architecture = @{ 'arm64' = @{ pre_install = 'test' } } }
        $manifest2 = @{ url = 'test'; pre_install = "'arm64'" }
        $manifest3 = @{ architecture = @{ 'arm64' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should -Be 'arm64'
        Get-SupportedArchitecture $manifest2 'arm64' | Should -Be 'arm64'
        Get-SupportedArchitecture $manifest3 'arm64' | Should -Be 'arm64'
    }
    It 'Should return "64bit" if unsupported on Windows 11' {
        $WindowsBuild = 22000
        $manifest1 = @{ url = 'test' }
        $manifest2 = @{ architecture = @{ '64bit' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should -Be '64bit'
        Get-SupportedArchitecture $manifest2 'arm64' | Should -Be '64bit'
    }
    It 'Should return "32bit" if unsupported on Windows 10' {
        $WindowsBuild = 19044
        $manifest2 = @{ url = 'test' }
        $manifest1 = @{ url = 'test'; architecture = @{ '64bit' = @{ pre_install = 'test' } } }
        $manifest3 = @{ architecture = @{ '64bit' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should -Be '32bit'
        Get-SupportedArchitecture $manifest2 'arm64' | Should -Be '32bit'
        Get-SupportedArchitecture $manifest3 'arm64' | Should -BeNullOrEmpty
    }
}

Describe 'Manifest Validator' -Tag 'Validator' {
    # Could not use backslash '\' in Linux/macOS for .NET object 'Scoop.Validator'
    BeforeAll {
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
        $schema = "$PSScriptRoot/../schema.json"
    }

    It 'Scoop.Validator is available' {
            ([System.Management.Automation.PSTypeName]'Scoop.Validator').Type | Should -Be 'Scoop.Validator'
    }
    It 'fails with broken schema' {
        $validator = New-Object Scoop.Validator("$PSScriptRoot/fixtures/manifest/broken_schema.json", $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/wget.json") | Should -BeFalse
        $validator.Errors.Count | Should -Be 1
        $validator.Errors | Select-Object -First 1 | Should -Match 'broken_schema.*(line 6).*(position 4)'
    }
    It 'fails with broken manifest' {
        $validator = New-Object Scoop.Validator($schema, $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/broken_wget.json") | Should -BeFalse
        $validator.Errors.Count | Should -Be 1
        $validator.Errors | Select-Object -First 1 | Should -Match 'broken_wget.*(line 5).*(position 4)'
    }
    It 'fails with invalid manifest' {
        $validator = New-Object Scoop.Validator($schema, $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/invalid_wget.json") | Should -BeFalse
        $validator.Errors.Count | Should -Be 16
        $validator.Errors | Select-Object -First 1 | Should -Match "Property 'randomproperty' has not been defined and the schema does not allow additional properties\."
        $validator.Errors | Select-Object -Last 1 | Should -Match 'Required properties are missing from object: version\.'
    }
}

Describe 'Manifest version variables' -Tag 'Scoop' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\core.ps1"
        . "$PSScriptRoot\..\lib\autoupdate.ps1"
        $raw = @'
{
    "version": "1.2.3",
    "url": "https://example.com/v$version/app-$version.zip",
    "extract_dir": "app-$majorVersion.$minorVersion",
    "post_install": "Write-Host $versionInfo",
    "architecture": {
        "64bit": {
            "url": "https://example.com/app-$cleanVersion-x64.zip",
            "pre_install": "$version"
        }
    },
    "autoupdate": {
        "url": "https://example.com/v$version/app-$version.zip"
    }
}
'@
    }
    It 'expands variables in regular properties' {
        $manifest = Expand-ManifestVariable ($raw | ConvertFrom-Json)
        $manifest.url | Should -Be 'https://example.com/v1.2.3/app-1.2.3.zip'
        $manifest.extract_dir | Should -Be 'app-1.2'
        $manifest.architecture.'64bit'.url | Should -Be 'https://example.com/app-123-x64.zip'
    }
    It 'leaves scripts, autoupdate and the source object untouched' {
        $source = $raw | ConvertFrom-Json
        $manifest = Expand-ManifestVariable $source
        $manifest.post_install | Should -Be 'Write-Host $versionInfo'
        $manifest.architecture.'64bit'.pre_install | Should -Be '$version'
        $manifest.autoupdate.url | Should -Be 'https://example.com/v$version/app-$version.zip'
        $source.url | Should -Be 'https://example.com/v$version/app-$version.zip'
        $source.architecture.'64bit'.url | Should -Be 'https://example.com/app-$cleanVersion-x64.zip'
    }
    It 'keeps templated properties on autoupdate' {
        $manifest = $raw | ConvertFrom-Json
        $manifest.autoupdate | Add-Member extract_dir 'app-$version'
        Update-ManifestProperty -Manifest $manifest -Property 'url', 'extract_dir' -Version '2.0.0' -Substitutions (Get-VersionSubstitution '2.0.0') | Should -BeTrue
        $manifest.version | Should -Be '2.0.0'
        $manifest.url | Should -Be 'https://example.com/v$version/app-$version.zip'
        $manifest.extract_dir | Should -Be 'app-$majorVersion.$minorVersion'
    }
    It 'hashes the templated url instead of autoupdate.url' {
        Mock HashHelper { $URL }
        $manifest = $raw | ConvertFrom-Json
        $manifest.url = 'https://mirror.example.com/app-$version.zip'
        $manifest | Add-Member hash 'old'
        $manifest.architecture.'64bit' | Add-Member hash 'old'
        $manifest.autoupdate | Add-Member architecture ([PSCustomObject]@{ '64bit' = [PSCustomObject]@{ url = 'https://example.com/other-$version.zip' } })
        Update-ManifestProperty -Manifest $manifest -Property 'hash' -Version '2.0.0' -Substitutions (Get-VersionSubstitution '2.0.0') | Out-Null
        $manifest.hash | Should -Be 'https://mirror.example.com/app-2.0.0.zip'
        $manifest.PSObject.Properties.Remove('hash')
        Update-ManifestProperty -Manifest $manifest -Property 'hash' -Version '2.0.0' -Substitutions (Get-VersionSubstitution '2.0.0') | Out-Null
        $manifest.architecture.'64bit'.hash | Should -Be 'https://example.com/app-200-x64.zip'
    }
    It 'passes raw templates to autoupdate when generating a user manifest' {
        . "$PSScriptRoot\..\lib\manifest.ps1"
        Mock Get-Manifest { 'app', (Expand-ManifestVariable ($raw | ConvertFrom-Json)), 'main', $null }
        Mock manifest_path { 'app.json' }
        Mock parse_json { $raw | ConvertFrom-Json }
        Mock usermanifestsdir { $TestDrive }
        Mock get_config { $false }
        Mock Invoke-AutoUpdate {}
        generate_user_manifest 'app' 'main' '2.0.0' 3>$null | Out-Null
        Should -Invoke Invoke-AutoUpdate -ParameterFilter { $Manifest.extract_dir -eq 'app-$majorVersion.$minorVersion' }
    }
}
