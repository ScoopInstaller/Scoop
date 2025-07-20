BeforeAll {
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\json.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\database.ps1"
}
Describe 'JSON parse and beautify' -Tag 'Scoop' {
    Context 'Parse JSON' {
        It 'success with valid json' {
            { parse_json "$PSScriptRoot\fixtures\manifest\wget.json" } | Should -Not -Throw
        }
    It 'fails with invalid json' {
        Mock warn {}
        Mock ConvertFrom-Json { throw "Invalid JSON" }
        $result = parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json"
        $result | Should -BeNullOrEmpty
        Should -Invoke -CommandName warn -Times 1 -ParameterFilter {
            $args[0] -like "*Error parsing JSON*"
        }
    }
    }
}
Describe 'Get-RelativePathCompat' -Tag 'Scoop' {
    It 'should return relative path for valid URIs' {
        Get-RelativePathCompat "C:\\path\from" "C:\\path\from\to" | Should -Be "to"
    }
    It 'should return absolute path for different schemes' {
        $result = Get-RelativePathCompat "C:\\path\from" "D:\\path\to"
        $result | Should -Be "D:\path\to"
    }
}
Describe 'Get-HistoricalManifestFromDB' -Tag 'Scoop' {
    BeforeAll {
        Mock ensure { return "C:\\test\\dir" }
        Mock usermanifestsdir { return "C:\\test\\manifests" }
        Mock Out-UTF8File {}
        Mock get_config { return $true }
    }
    It 'should return manifest from database if available' {
        Mock Get-ScoopDBItem { $mockDbResult = [PSCustomObject] @{ Rows = @( [PSCustomObject] @{ manifest = '{"version": "1.2.3"}' }) } ; return $mockDbResult }
        $result = Get-HistoricalManifestFromDB 'testapp' 'testbucket' '1.2.3'
        $result.path | Should -Match 'testapp.json'
        $result.source | Should -Be "sqlite_exact_match"
    }
    It 'should return null if database disabled' {
        Mock get_config { return $false }
        $result = Get-HistoricalManifestFromDB 'testapp' 'testbucket' '1.2.3'
        $result | Should -BeNullOrEmpty
    }
}
Describe 'Get-HistoricalManifest' -Tag 'Scoop' {
    BeforeAll {
        Mock ensure { return "C:\\test\\dir" }
        Mock usermanifestsdir { return "C:\\test\\manifests" }
        Mock Out-UTF8File {}
        Mock get_config { return $true }
    }
    It 'should return manifest using database if available' {
        Mock Get-ScoopDBItem { $mockDbResult = [PSCustomObject] @{ Rows = @( [PSCustomObject] @{ manifest = '{"version": "2.3.4"}' }) } ; return $mockDbResult }
        $result = Get-HistoricalManifest 'testapp' 'testbucket' '2.3.4'
        $result.path | Should -Match 'testapp.json'
        $result.source | Should -Be "sqlite_exact_match"
    }
    It 'should return null if no bucket provided' {
        $result = Get-HistoricalManifest 'testapp' $null '2.3.4'
        $result | Should -BeNullOrEmpty
    }
}
Describe 'JSON parse and beautify' -Tag 'Scoop' {
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
