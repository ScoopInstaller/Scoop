BeforeAll {
    . "$PSScriptRoot\..\lib\json.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\buckets.ps1"
    . "$PSScriptRoot\..\lib\versions.ps1"
    . "$PSScriptRoot\..\lib\database.ps1"
    . "$PSScriptRoot\..\lib\autoupdate.ps1"
}

Describe 'JSON parse and beautify' -Tag 'Scoop' {
    Context 'Parse JSON' {
        It 'success with valid json' {
            $null = & { parse_json "$PSScriptRoot\fixtures\manifest\wget.json" }
            $parsed = parse_json "$PSScriptRoot\fixtures\manifest\wget.json"
            $parsed | Should-NotBeNull
        }
        It 'returns null and warns with invalid json' {
            Mock warn {}
            & { parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json" }
            $parsed = parse_json "$PSScriptRoot\fixtures\manifest\broken_wget.json"
            $parsed | Should-BeNull
            Should-Invoke -CommandName warn -Times 1
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
            $correct.CompareTo($pretty_json) | Should-Be 0
        }
    }
}

Describe 'Handle ARM64 and correctly fallback' -Tag 'Scoop' {
    It 'Should return "arm64" if supported' {
        $manifest1 = @{ url = 'test'; architecture = @{ 'arm64' = @{ pre_install = 'test' } } }
        $manifest2 = @{ url = 'test'; pre_install = "'arm64'" }
        $manifest3 = @{ architecture = @{ 'arm64' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should-Be 'arm64'
        Get-SupportedArchitecture $manifest2 'arm64' | Should-Be 'arm64'
        Get-SupportedArchitecture $manifest3 'arm64' | Should-Be 'arm64'
    }
    It 'Should return "64bit" if unsupported on Windows 11' {
        $WindowsBuild = 22000
        $manifest1 = @{ url = 'test' }
        $manifest2 = @{ architecture = @{ '64bit' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should-Be '64bit'
        Get-SupportedArchitecture $manifest2 'arm64' | Should-Be '64bit'
    }
    It 'Should return "32bit" if unsupported on Windows 10' {
        $WindowsBuild = 19044
        $manifest2 = @{ url = 'test' }
        $manifest1 = @{ url = 'test'; architecture = @{ '64bit' = @{ pre_install = 'test' } } }
        $manifest3 = @{ architecture = @{ '64bit' = @{ url = 'test' } } }
        Get-SupportedArchitecture $manifest1 'arm64' | Should-Be '32bit'
        Get-SupportedArchitecture $manifest2 'arm64' | Should-Be '32bit'
        Get-SupportedArchitecture $manifest3 'arm64' | Should-BeNull
    }
}

Describe 'Manifest Validator' -Tag 'Validator' {
    # Could not use backslash '\' in Linux/macOS for .NET object 'Scoop.Validator'
    BeforeAll {
        Add-Type -Path "$PSScriptRoot\..\supporting\validator\bin\Scoop.Validator.dll"
        $schema = "$PSScriptRoot/../schema.json"
    }

    It 'Scoop.Validator is available' {
        ([System.Management.Automation.PSTypeName]'Scoop.Validator').Type | Should-Be 'Scoop.Validator'
    }
    It 'fails with broken schema' {
        $validator = New-Object Scoop.Validator("$PSScriptRoot/fixtures/manifest/broken_schema.json", $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/wget.json") | Should-BeFalse
        $validator.Errors.Count | Should-Be 1
        $validator.Errors | Select-Object -First 1 | Should-MatchString 'broken_schema.*(line 6).*(position 4)'
    }
    It 'fails with broken manifest' {
        $validator = New-Object Scoop.Validator($schema, $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/broken_wget.json") | Should-BeFalse
        $validator.Errors.Count | Should-Be 1
        $validator.Errors | Select-Object -First 1 | Should-MatchString 'broken_wget.*(line 5).*(position 4)'
    }
    It 'fails with invalid manifest' {
        $validator = New-Object Scoop.Validator($schema, $true)
        $validator.Validate("$PSScriptRoot/fixtures/manifest/invalid_wget.json") | Should-BeFalse
        $validator.Errors.Count | Should-Be 16
        $validator.Errors | Select-Object -First 1 | Should-MatchString "Property 'randomproperty' has not been defined and the schema does not allow additional properties\."
        $validator.Errors | Select-Object -Last 1 | Should-MatchString 'Required properties are missing from object: version\.'
    }
}

Describe 'Find-HistoricalManifestInCache' -Tag 'Scoop' {
    It 'returns $null when sqlite cache disabled' {
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        $result = Find-HistoricalManifestInCache 'foo' 'main' '1.0.0'
        $result | Should-BeNull
    }

    It 'returns manifest text and version when cache has exact match' {
        $tempUM = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock get_config -ParameterFilter { $name -in @('use_sqlite_cache', 'use_git_history') } { $true }
        Mock Get-ScoopDBItem {
            $dt = New-Object System.Data.DataTable
            [void]$dt.Columns.Add('manifest')
            $row = $dt.NewRow()
            $row['manifest'] = '{"version":"1.2.3"}'
            [void]$dt.Rows.Add($row)
            Write-Output $dt -NoEnumerate
        }
        Mock ensure {}
        $result = Find-HistoricalManifestInCache 'foo' 'main' '1.2.3'
        $result | Should-NotBeNull
        $result.version | Should-Be '1.2.3'
        $result.ManifestText | Should-MatchString '"version":"1.2.3"'
    }
}

Describe 'Find-HistoricalManifestInGit' -Tag 'Scoop' {
    BeforeEach {
        $bucketRoot = 'C:\b\root'
        $innerBucket = 'C:\b\root\bucket'
        Mock get_config -ParameterFilter { $name -eq 'use_git_history' } { $true }
        Mock Find-BucketDirectory -ParameterFilter { $Root } { $bucketRoot }
        Mock Find-BucketDirectory -ParameterFilter { -not $Root } { $innerBucket }
        Mock Test-Path -ParameterFilter { $Path -eq (Join-Path $bucketRoot '.git') } { $true }
        Mock Test-Path -ParameterFilter { $Path -eq $innerBucket -and $PathType -eq 'Container' } { $true }
    }

    It 'returns $null when git history search disabled' {
        Mock get_config -ParameterFilter { $name -eq 'use_git_history' } { $false }
        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-BeNull
    }

    It 'returns manifest text on version match' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"2.0.0"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' } { return '{"version":"1.0.0"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' } { @('abcdef0123456789') }

        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-NotBeNull
        $result.version | Should-Be '1.0.0'
        $result.ManifestText | Should-MatchString '"version":"1.0.0"'
    }

    It 'short-circuits via HEAD fast-path when HEAD already has the requested version' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"1.0.0"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' } { @('shouldnotbeused') }

        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-NotBeNull
        $result.version | Should-Be '1.0.0'
        $result.source | Should-Be 'git_manifest:HEAD'
        Should-Invoke -CommandName Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' } -Times 0
    }

    It 'falls back to -S pickaxe when -G yields no commits' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"2.0.0"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-G' } { return @() }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-S' } { return @('feedface') }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -notlike 'HEAD*' } { return '{"version":"1.0.0"}' }

        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-NotBeNull
        $result.version | Should-Be '1.0.0'
        $result.source | Should-Be 'git_manifest:feedface'
    }

    It 'returns $null when $h / $h^ walk yields no manifest' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"9.9.9"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -match '^[a-f0-9]+\^?:' } { return '{"version":"9.9.9"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-G' } { return @('aaaa1111') }

        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-BeNull
    }

    It 'walks older pickaxe hits when the newest ones are later releases' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"5.20.2"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-G' } { return @('newer1111', 'older2222') }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -eq 'newer1111:bucket/foo.json' } { return '{"version":"5.20.2"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -eq 'newer1111^:bucket/foo.json' } { return '{"version":"5.20.1"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -eq 'older2222:bucket/foo.json' } { return '{"version":"5.20"}' }

        $result = Find-HistoricalManifestInGit 'foo' 'main' '5.20'
        $result | Should-NotBeNull
        $result.version | Should-Be '5.20'
        $result.source | Should-Be 'git_manifest:older2222'
    }

    It 'anchors the pickaxe pattern so a longer version cannot match' {
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'show' -and $ArgumentList[1] -like 'HEAD*' } { return '{"version":"5.20.2"}' }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-G' } {
            $script:pickaxePattern = $ArgumentList[[Array]::IndexOf($ArgumentList, '-G') + 1]
            return @()
        }
        Mock Invoke-Git -ParameterFilter { $ArgumentList[0] -eq 'log' -and $ArgumentList -contains '-S' } { return @() }

        $null = Find-HistoricalManifestInGit 'foo' 'main' '5.20'
        $script:pickaxePattern | Should-Be 'version.: .5\.20([^0-9A-Za-z._+-]|$)'
    }

    It 'returns $null when inner bucket directory cannot be found' {
        Mock Test-Path -ParameterFilter { $Path -eq $innerBucket -and $PathType -eq 'Container' } { $false }
        Mock warn {}
        $result = Find-HistoricalManifestInGit 'foo' 'main' '1.0.0'
        $result | Should-BeNull
    }
}

Describe 'Find-HistoricalManifest (orchestrator)' -Tag 'Scoop' {
    It 'returns $null when both cache and git miss' {
        Mock get_config -ParameterFilter { $name -in @('use_sqlite_cache', 'use_git_history') } { $true }
        Mock Find-HistoricalManifestInCache { $null }
        Mock Find-HistoricalManifestInGit { $null }
        $result = Find-HistoricalManifest 'foo' 'main' '1.0.0'
        $result | Should-BeNull
    }
}

Describe 'Write-ManifestToUserCache' -Tag 'Scoop' {
    It 'writes to $App.json (no version suffix) so downstream install path does not duplicate version' {
        $umdir = Join-Path $env:TEMP ("ScoopUM_" + [guid]::NewGuid().ToString('N'))
        Mock usermanifestsdir { $umdir }
        $p = Write-ManifestToUserCache -App 'foo' -ManifestText '{"version":"1.0.0"}'
        $p | Should-Be (Join-Path $umdir 'foo.json')
        Test-Path $p | Should-BeTrue
        Remove-Item -Recurse -Force $umdir -ErrorAction SilentlyContinue
    }
}

Describe 'generate_user_manifest (history-aware)' -Tag 'Scoop' {
    It 'returns manifest_path when versions match' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '1.0.0' }, 'main', $null }
        Mock manifest_path { 'C:\path\foo.json' }
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should-Be 'C:\path\foo.json'
    }

    It 'prefers history orchestrator hit (cache) when enabled' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -in @('use_sqlite_cache', 'use_git_history') } { $true }
        Mock Find-HistoricalManifest { @{ path = 'C:\cache\foo.json'; version = '1.0.0'; source = 'sqlite_exact_match' } }

        Mock info {}
        Mock warn {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should-Be 'C:\cache\foo.json'
        Should-Invoke -CommandName Find-HistoricalManifest -Times 1

    }

    It 'falls back to git history when cache misses' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -in @('use_sqlite_cache', 'use_git_history') } { $true }
        Mock Find-HistoricalManifest { @{ path = 'C:\git\foo.json'; version = '1.0.0'; source = 'git_manifest:hash' } }
        Mock info {}
        Mock warn {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should-Be 'C:\git\foo.json'
        Should-Invoke -CommandName Find-HistoricalManifest -Times 1

    }

    It 'uses autoupdate when no history found and autoupdate exists' {
        $umdir = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '2.0.0'; autoupdate = @{} }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Find-HistoricalManifest { $null }

        Mock ensure {}
        Mock usermanifestsdir { $umdir }
        Mock Invoke-AutoUpdate {}
        Mock warn {}
        Mock info {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should-Be (Join-Path $umdir 'foo.json')
        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -match "No historical manifest found for 'foo@1\.0\.0'; attempting autoupdate" }
    }

    It 'returns $null when autoupdate fails (caller surfaces the error)' {
        $umdir = Join-Path $env:TEMP 'ScoopTestsUM'
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '2.0.0'; autoupdate = @{} }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Find-HistoricalManifest { $null }
        Mock ensure {}
        Mock usermanifestsdir { $umdir }
        Mock Invoke-AutoUpdate { throw 'fail' }
        Mock warn {}
        Mock info {}
        $p = generate_user_manifest 'foo' 'main' '1.0.0'
        $p | Should-BeNull
    }

    It 'aborts when no history and no autoupdate' {
        Mock Get-Manifest -ParameterFilter { $app -eq 'main/foo' } { 'foo', [pscustomobject]@{ version = '2.0.0' }, 'main', $null }
        Mock get_config -ParameterFilter { $name -eq 'use_sqlite_cache' } { $false }
        Mock Find-HistoricalManifest { $null }

        Mock warn {}
        Mock info {}
        { generate_user_manifest 'foo' 'main' '1.0.0' } | Should-Throw
    }
}

Describe 'manifest bucket auto-discovery' -Tag 'Scoop' {
    It 'discovers bucket for bare app name' {
        Mock Get-LocalBucket { @('main') }
        Mock manifest_path { 'C:\fake.json' }
        Mock parse_json { @{ version = '1.0.0' } }
        Mock warn {}
        $m, $b = Find-AppBucket 'foo'
        $b | Should-Be 'main'
        $m.version | Should-Be '1.0.0'
    }

    It 'returns $null when app not found in any bucket' {
        Mock Get-LocalBucket { @('main') }
        Mock manifest_path { 'C:\nonexistent.json' }
        Mock parse_json { $null }
        Mock warn {}
        $m, $b = Find-AppBucket 'foo'
        $m | Should-BeNull
        $b | Should-BeNull
    }

    It 'url used when bucket is null' {
        Mock url_manifest { @{ version = '1.0.0' } }
        $m = manifest 'foo' $null 'https://example.com/foo.json'
        $m.version | Should-Be '1.0.0'
        Should-Invoke url_manifest -Times 1
    }
}

Describe 'manifest migrations' -Tag 'Scoop' {
    BeforeAll {
        Function Write-MigrationMap([string] $bucket, [string] $app, [string] $target) {
            $dir = Join-Path $migrationTestRoot $bucket
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dir '.scoop-migrations.json'), ('{"' + $app + '":"' + $target + '"}'))
        }

        Function Write-AppManifest([string] $bucket, [string] $app, [string] $version) {
            $dir = Join-Path $migrationTestRoot "$bucket\bucket"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dir "$app.json"), ('{"version":"' + $version + '"}'))
        }
    }

    BeforeEach {
        $migrationTestRoot = Join-Path $env:TEMP ("ScoopMigrationTests_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $migrationTestRoot | Out-Null
        $script:localBuckets = @('extras', 'main')
        Mock Get-LocalBucket { $script:localBuckets }
        Mock Find-BucketDirectory {
            $repo = Join-Path $migrationTestRoot $Name
            if ($Root -or !(Test-Path (Join-Path $repo 'bucket'))) {
                $repo
            } else {
                Join-Path $repo 'bucket'
            }
        }
        Mock warn {}
        Mock error {}
        Mock installed { $false }
    }

    AfterEach {
        Remove-Item -LiteralPath $migrationTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'prefers an exact manifest over a migration record' {
        Write-AppManifest 'main' 'old-name' '1.0.0'
        Write-AppManifest 'main' 'new-name' '2.0.0'
        Write-MigrationMap 'main' 'old-name' 'new-name'

        $app, $manifest, $null, $null = Get-Manifest 'old-name'

        $app | Should-Be 'old-name'
        $manifest.version | Should-Be '1.0.0'
    }

    It 'follows a record of another bucket after the first one moved it there' {
        Write-AppManifest 'extras' 'final' '3.0.0'
        Write-MigrationMap 'main' 'old-name' 'extras/middle'
        Write-MigrationMap 'extras' 'middle' 'final'

        $app, $manifest, $bucket, $null = Get-Manifest 'old-name'

        $app | Should-Be 'final'
        $bucket | Should-Be 'extras'
        $manifest.version | Should-Be '3.0.0'
    }

    It 'stops a migration that points back at its own start' {
        Write-MigrationMap 'main' 'old-name' 'extras/middle'
        Write-MigrationMap 'extras' 'middle' 'main/old-name'

        $app, $manifest, $null, $null = Get-Manifest 'old-name'

        $manifest | Should-BeNull
        Should-Invoke -CommandName error -ParameterFilter { $msg -match 'circle' } -Times 1 -Exactly
    }

    It 'does not use another bucket that happens to have the name' {
        $script:localBuckets = @('main', 'my-versions')
        Write-AppManifest 'my-versions' 'new-name' '2.0.0'
        Write-MigrationMap 'main' 'old-name' 'versions/new-name'

        $app, $manifest, $bucket, $null = Get-Manifest 'old-name'

        $manifest | Should-BeNull
        $bucket | Should-Be 'versions'
    }

    It 'reports the bucket to add when the target bucket is not installed' {
        Write-MigrationMap 'main' 'old-name' 'versions/new-name'
        Mock known_bucket_repo { 'https://github.com/ScoopInstaller/Versions' }

        $app, $manifest, $bucket, $null = Get-Manifest 'old-name'

        $manifest | Should-BeNull
        $app | Should-Be 'new-name'
        $bucket | Should-Be 'versions'
        Should-Invoke -CommandName error -ParameterFilter { $msg -match 'scoop bucket add versions' } -Times 1 -Exactly
    }

    It 'prefers the bucket the app came from over another one that also has the name' {
        Write-AppManifest 'main' 'new-name' '2.0.0'
        Write-AppManifest 'extras' 'new-name' '9.0.0'
        Write-MigrationMap 'main' 'old-name' 'new-name'

        $null, $manifest, $bucket, $null = Get-Manifest 'old-name'

        $manifest.version | Should-Be '2.0.0'
        $bucket | Should-Be 'main'
    }

    It 'keeps the migration file out of the manifests of a flat bucket' {
        $dir = Join-Path $migrationTestRoot 'flat'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dir '.scoop-migrations.json'), '{"old-name":"new-name"}')
        [System.IO.File]::WriteAllText((Join-Path $dir 'new-name.json'), '{"version":"1.0.0"}')
        $script:localBuckets = @('flat')

        $names = @(Get-BucketManifestFiles 'flat' | ForEach-Object { $_.Name })

        $names.Count | Should-Be 1
        $names[0] | Should-Be 'new-name.json'
    }

    Context 'resolving one record' {
        It 'reads only the map of the given source bucket' {
            Write-AppManifest 'extras' 'new-name' '2.0.0'
            Write-MigrationMap 'extras' 'old-name' 'new-name'

            Find-AppMigration 'old-name' 'main' | Should-BeNull
            (Find-AppMigration 'old-name' $null).App | Should-Be 'new-name'
        }

        It 'rejects an invalid target' {
            $cases = @(
                @{ target = 'main/'; why = 'the app part is empty' }
                @{ target = '/name'; why = 'the bucket part is empty' }
                @{ target = ' main/name'; why = 'it holds leading whitespace' }
                @{ target = 'main/ name'; why = 'it holds whitespace after the separator' }
                @{ target = 'main/new*name'; why = 'it holds a character that is invalid in a file name' }
                @{ target = 'main/name.json'; why = 'it holds a .json suffix' }
                @{ target = 'main/..'; why = 'it escapes the bucket' }
                @{ target = 'main/name@1.0'; why = 'it pins a version' }
                @{ target = 5; why = 'it is not a string' }
            )
            foreach ($case in $cases) {
                Get-MigrationTarget 'old-name' $case.target 'main' | Should-BeNull -Because $case.why
            }
            Should-Invoke -CommandName warn -Times $cases.Count -Exactly
        }

        It 'rejects a map that is not an object' {
            $dir = Join-Path $migrationTestRoot 'main'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $dir '.scoop-migrations.json'), '["old-name"]')

            Get-BucketMigrations 'main' | Should-BeNull
            Should-Invoke -CommandName warn -Times 1 -Exactly
        }
    }

    Context 'installed app' {
        BeforeEach {
            Mock installed { $true }
            Mock Select-CurrentVersion { '1.0.0' }
        }

        It 'resolves it to the name its own bucket moved it to' {
            Write-AppManifest 'extras' 'new-name' '2.0.0'
            Write-MigrationMap 'main' 'old-name' 'extras/new-name'
            Mock install_info { [pscustomobject]@{ bucket = 'main'; url = $null } }
            Mock installed_manifest { [pscustomobject]@{ version = '1.0.0' } }

            $app, $manifest, $bucket, $null = Get-Manifest 'old-name'

            $app | Should-Be 'new-name'
            $bucket | Should-Be 'extras'
            $manifest.version | Should-Be '2.0.0'
        }

        It 'does not let another bucket redirect it' {
            Write-AppManifest 'main' 'new-name' '2.0.0'
            Write-MigrationMap 'extras' 'old-name' 'main/new-name'
            Mock install_info { [pscustomobject]@{ bucket = 'main'; url = $null } }
            Mock installed_manifest { [pscustomobject]@{ version = '1.0.0' } }

            $app, $manifest, $null, $null = Get-Manifest 'old-name'

            $app | Should-Be 'old-name'
            $manifest | Should-BeNull
        }

        It 'does not redirect it when the source bucket is unknown' {
            Write-AppManifest 'main' 'new-name' '2.0.0'
            Write-MigrationMap 'main' 'old-name' 'new-name'
            Mock install_info { [pscustomobject]@{ bucket = $null; url = 'old-name.json' } }
            Mock installed_manifest { [pscustomobject]@{ version = '1.0.0' } }

            $app, $manifest, $null, $null = Get-Manifest 'old-name'

            $app | Should-Be 'old-name'
            $manifest.version | Should-Be '1.0.0'
        }
    }
}
