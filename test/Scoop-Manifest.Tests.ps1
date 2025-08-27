BeforeAll {
    . "$PSScriptRoot\..\lib\json.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\buckets.ps1"
    . "$PSScriptRoot\..\lib\database.ps1"
    . "$PSScriptRoot\..\lib\autoupdate.ps1"
}

Describe 'JSON parse and beautify' -Tag 'Scoop' {
    Context 'Parse JSON' {
        It 'success with valid json' {
            { parse_json "$PSScriptRoot\fixtures\manifest\wget.json" } | Should -Not -Throw
            $parsed = parse_json "$PSScriptRoot\fixtures\manifest\wget.json"
            $parsed | Should -Not -Be $null
        }
        It 'returns null and warns with invalid json' {
            Mock warn {}
            { parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json" } | Should -Not -Throw
            $parsed = parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json"
            $parsed | Should -Be $null
            Should -Invoke -CommandName warn -Times 1
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

Describe 'Get-RelativePathCompat' -Tag 'Scoop' {
    It 'returns relative path for child path' {
        $from = 'C:\root\bucket'
        $to = 'C:\root\bucket\foo\bar.json'
        Get-RelativePathCompat $from $to | Should -Be 'foo\bar.json'
    }
    It 'returns original when different drive/scheme' {
        $from = 'C:\root\bucket'
        $to = 'D:\other\file.json'
        Get-RelativePathCompat $from $to | Should -Be $to
    }
}

Describe 'Get-HistoricalManifestFromDB' -Tag 'Scoop' {
    It 'returns $null when sqlite cache disabled' {
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        $result = Get-HistoricalManifestFromDB 'foo' 'main' '1.0.0'
        $result | Should -Be $null
    }

    It 'returns path and version when cache has exact match' {
        $tempUM = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $true }
        Mock Get-ScoopDBItem { [pscustomobject]@{ Rows = @([pscustomobject]@{ manifest = '{"version":"1.2.3"}' }) } }
        Mock ensure {}
        Mock usermanifestsdir { $tempUM }
        Mock Out-UTF8File {}

        $result = Get-HistoricalManifestFromDB 'foo' 'main' '1.2.3'
        $result | Should -Not -BeNullOrEmpty
        $result.version | Should -Be '1.2.3'
        $result.path | Should -Match '\\foo\.json$'
        Should -Invoke -CommandName Out-UTF8File -Times 1
    }
}

Describe 'Get-HistoricalManifestFromGitHistory' -Tag 'Scoop' {
    It 'returns $null when git history search disabled' {
        Mock get_config -ParameterFilter { $name -eq 'use_git_history' } { $false }
        $result = Get-HistoricalManifestFromGitHistory 'foo' 'main' '1.0.0'
        $result | Should -Be $null
    }

    It 'returns manifest path on commit message exact match' {
        $bucketRoot = 'C:\b\root'
        $innerBucket = 'C:\b\root\bucket'
        $umdir = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock get_config -ParameterFilter { $name -eq 'use_git_history' } { $true }
        Mock Find-BucketDirectory -ParameterFilter { $Root } { $bucketRoot }
        Mock Find-BucketDirectory -ParameterFilter { -not $Root } { $innerBucket }
        Mock Test-Path -ParameterFilter { $Path -eq (Join-Path $bucketRoot '.git') } { $true }
        Mock Test-Path -ParameterFilter { $Path -eq $innerBucket -and $PathType -eq 'Container' } { $true }
        Mock usermanifestsdir { $umdir }
        Mock Out-UTF8File {}
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' } { $global:LASTEXITCODE = 0; return '{"version":"1.0.0"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' } { @('abcdef0123456789','foo: Update to version 1.0.0') }

        $result = Get-HistoricalManifestFromGitHistory 'foo' 'main' '1.0.0'
        $result | Should -Not -BeNullOrEmpty
        $result.path | Should -Match '\\foo\.json$'
        $result.version | Should -Be '1.0.0'
        Should -Invoke -CommandName Out-UTF8File -Times 1
    }
}

Describe 'generate_user_manifest (history-aware)' -Tag 'Scoop' {
    It 'returns manifest_path when versions match' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='1.0.0' }, 'main', $null }
        Mock manifest_path { 'C:\path\foo.json' }
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should -Be 'C:\path\foo.json'
    }

    It 'prefers sqlite cache when enabled and hit' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $true }
        Mock Get-HistoricalManifestFromDB { @{ path = 'C:\cache\foo.json'; version = '1.0.0'; source='sqlite_exact_match' } }
        Mock Get-HistoricalManifestFromGitHistory { $null }
        Mock info {}
        Mock warn {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should -Be 'C:\cache\foo.json'
        Should -Invoke -CommandName Get-HistoricalManifestFromDB -Times 1
        Should -Invoke -CommandName Get-HistoricalManifestFromGitHistory -Times 0
    }

    It 'falls back to git history when cache misses' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $true }
        Mock Get-HistoricalManifestFromDB { $null }
        Mock Get-HistoricalManifestFromGitHistory { @{ path = 'C:\git\foo.json'; version = '1.0.0'; source='git_manifest:hash' } }
        Mock info {}
        Mock warn {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should -Be 'C:\git\foo.json'
        Should -Invoke -CommandName Get-HistoricalManifestFromDB -Times 1
        Should -Invoke -CommandName Get-HistoricalManifestFromGitHistory -Times 1
    }

    It 'uses autoupdate when no history found and autoupdate exists' {
        $umdir = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='2.0.0'; autoupdate=@{} }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Get-HistoricalManifestFromDB { $null }
        Mock Get-HistoricalManifestFromGitHistory { $null }
        Mock ensure {}
        Mock usermanifestsdir { $umdir }
        Mock Invoke-AutoUpdate {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should -Be (Join-Path $umdir 'foo.json')
    }

    It 'on autoupdate failure retries git and returns when found' {
        $umdir = Join-Path $env:TEMP 'ScoopTestsUM'
        $call = 0
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='2.0.0'; autoupdate=@{} }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Get-HistoricalManifestFromDB { $null }
        Mock Get-HistoricalManifestFromGitHistory { $script:call += 1; if ($script:call -eq 1) { $null } else { @{ path = 'C:\git\foo.json'; version='1.0.0' } } }
        Mock ensure {}
        Mock usermanifestsdir { $umdir }
        Mock Invoke-AutoUpdate { throw 'fail' }
        Mock warn {}
        Mock info {}
        Mock Write-Host {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should -Be 'C:\git\foo.json'
    }

    It 'aborts when no history and no autoupdate' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version='2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Get-HistoricalManifestFromDB { $null }
        Mock Get-HistoricalManifestFromGitHistory { $null }
        Mock warn {}
        Mock info {}
        Mock abort { throw 'aborted' }
        { generate_user_manifest 'foo' 'main' '1.0.0' } | Should -Throw
    }
}

