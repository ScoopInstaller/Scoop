BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
    . "$PSScriptRoot\..\lib\decompress.ps1"
    . "$PSScriptRoot\..\lib\json.ps1"
    . "$PSScriptRoot\..\lib\shortcuts.ps1"
    . "$PSScriptRoot\..\lib\database.ps1"
    . "$PSScriptRoot\..\lib\autoupdate.ps1"
    . "$PSScriptRoot\..\lib\psmodules.ps1"
}
Describe 'install_app' -Tag 'Scoop' {
    BeforeAll {
        # Mock all required functions and external dependencies
        Mock Get-Manifest { return @('testapp', @{ version = '1.0.0' }, 'testbucket', $null) }
        Mock Get-SupportedArchitecture { return '64bit' }
        Mock ensure { return "C:\test\dir" }
        Mock versiondir { return "C:\test\dir" }
        Mock persistdir { return "C:\test\persist" }
        Mock usermanifestsdir { return "C:\test\manifests" }
        Mock ensure_install_dir_not_in_path {}
        Mock link_current { return "C:\test\dir" }
        Mock create_shims {}
        Mock create_startmenu_shortcuts {}
        Mock Invoke-AutoUpdate { return "C:\temp\manifests\testapp.json" }
        Mock Get-ScoopDBItem { return [PSCustomObject]@{ Rows = @() } }
        Mock install_psmodule {}
        Mock env_add_path {}
        Mock env_set {}
        Mock persist_data {}
        Mock persist_permission {}
        Mock save_installed_manifest {}
        Mock save_install_info {}
        Mock show_notes {}
        Mock Write-Output {}
        Mock success {}
    }
    It 'should handle try-catch block successfully' {
        Mock Invoke-ScoopDownload { "file.txt" }
        Mock Invoke-Extraction {}
        Mock Invoke-HookScript {}
        Mock Invoke-Installer {}
        { install_app 'testapp' '64bit' $false $false } | Should -Not -Throw
        Should -Invoke -CommandName Invoke-ScoopDownload -Times 1
        Should -Invoke -CommandName Invoke-Extraction -Times 1
    }
}
Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should -Be 'foobar'
    }
}
Describe 'is_in_dir' -Tag 'Scoop', 'Windows' {
    It 'should work correctly' {
        is_in_dir 'C:\test' 'C:\foo' | Should -BeFalse
        is_in_dir 'C:\test' 'C:\test\foo\baz.zip' | Should -BeTrue
        is_in_dir "$PSScriptRoot\..\" "$PSScriptRoot" | Should -BeFalse
    }
}
Describe 'env add and remove path' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        # test data
        $manifest = @{
            'env_add_path' = @('foo', 'bar', '.', '..')
        }
        $testdir = Join-Path $PSScriptRoot 'path-test-directory'
        $global = $false
    }
    It 'should concat the correct path' {
        Mock Add-Path {}
        Mock Remove-Path {}
        # adding
        env_add_path $manifest $testdir $global
        Should -Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should -Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should -Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should -Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }
        env_rm_path $manifest $testdir $global
        Should -Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should -Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should -Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should -Invoke -CommandName Remove-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }
    }
}
Describe 'shim_def' -Tag 'Scoop' {
    It 'should use strings correctly' {
        $target, $name, $shimArgs = shim_def 'command.exe'
        $target | Should -Be 'command.exe'
        $name | Should -Be 'command'
        $shimArgs | Should -BeNullOrEmpty
    }
    It 'should expand the array correctly' {
        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar')
        $target | Should -Be 'foo.exe'
        $name | Should -Be 'bar'
        $shimArgs | Should -BeNullOrEmpty
        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar', '--test')
        $target | Should -Be 'foo.exe'
        $name | Should -Be 'bar'
        $shimArgs | Should -Be '--test'
    }
}
Describe 'persist_def' -Tag 'Scoop' {
    It 'parses string correctly' {
        $source, $target = persist_def 'test'
        $source | Should -Be 'test'
        $target | Should -Be 'test'
    }
    It 'should handle sub-folder' {
        $source, $target = persist_def 'foo/bar'
        $source | Should -Be 'foo/bar'
        $target | Should -Be 'foo/bar'
    }
    It 'should handle arrays' {
        # both specified
        $source, $target = persist_def @('foo', 'bar')
        $source | Should -Be 'foo'
        $target | Should -Be 'bar'
        # only first specified
        $source, $target = persist_def @('foo')
        $source | Should -Be 'foo'
        $target | Should -Be 'foo'
        # null value specified
        $source, $target = persist_def @('foo', $null)
        $source | Should -Be 'foo'
        $target | Should -Be 'foo'
    }
}
Describe 'Get-RelativePathCompat' -Tag 'Scoop' {
    It 'should return relative path using PowerShell Core method when available' {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $result = Get-RelativePathCompat "C:\test\from" "C:\test\from\to\file.txt"
            $result | Should -Match "to[\\\/]file\.txt"
        }
    }
    It 'should fallback to URI method when PowerShell Core method fails or on Windows PowerShell' {
        $result = Get-RelativePathCompat "C:\test\from\" "C:\test\from\to\file.txt"
        $result | Should -Not -BeNullOrEmpty
    }
    It 'should handle different schemes gracefully' {
        # This test may behave differently on different systems
        # The function should return something meaningful when schemes differ
        $result = Get-RelativePathCompat "file:///C:/test/from/" "http://example.com/file.txt"
        $result | Should -Not -BeNullOrEmpty
    }
}
Describe 'Get-HistoricalManifestFromDB' -Tag 'Scoop' {
    BeforeAll {
        Mock get_config {
            param($key)
            if ($key -eq 'USE_SQLITE_CACHE') { return $true }
            return $false
        }
        Mock Get-Command { return $true }
        Mock Get-ScoopDBItem { return [PSCustomObject]@{ Rows = @() } }
        Mock ensure { return "C:\temp\manifests" }
        Mock usermanifestsdir { return "C:\temp\manifests" }
        Mock Out-UTF8File {}
    }
    It 'should return null when SQLite cache is disabled' {
        Mock get_config { return $false }
        $result = Get-HistoricalManifestFromDB 'testapp' 'main' '1.0.0'
        $result | Should -BeNullOrEmpty
    }
    It 'should return null when Get-ScoopDBItem command not available' {
        Mock Get-Command { return $null }
        $result = Get-HistoricalManifestFromDB 'testapp' 'main' '1.0.0'
        $result | Should -BeNullOrEmpty
    }
    It 'should return manifest for exact version match' {
        Mock Get-ScoopDBItem {
            $mockRow = [PSCustomObject]@{ manifest = '{"version": "1.0.0", "description": "Test app"}'; version = '1.0.0' }
            return [PSCustomObject]@{ Rows = @($mockRow) }
        }
        Mock ConvertFrom-Json { return [PSCustomObject]@{ version = '1.0.0'; description = 'Test app' } }
        $result = Get-HistoricalManifestFromDB 'testapp' 'main' '1.0.0'
        $result.version | Should -Be '1.0.0'
        $result.source | Should -Be 'sqlite_exact_match'
        $result.path | Should -Match 'testapp\.json'
    }
    It 'should return null when exact version not available' {
        Mock Get-ScoopDBItem {
            param($Name, $Bucket, $Version)
            # Always return empty results since we only support exact matches now
            return [PSCustomObject]@{ Rows = @() }
        }
        $result = Get-HistoricalManifestFromDB 'testapp' 'main' '1.0'
        $result | Should -BeNullOrEmpty
    }
}
Describe 'Get-HistoricalManifest' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-HistoricalManifestFromDB { return $null }
        Mock get_config {
            param($key, $default)
            if ($key -eq 'USE_GIT_HISTORY') { return $default }
            return $false
        }
    }
    It 'should return database result when available' {
        Mock Get-HistoricalManifestFromDB {
            return @{
                path = "C:\temp\testapp.json"
                version = "1.0.0"
                source = "sqlite_exact_match"
            }
        }
        $result = Get-HistoricalManifest 'testapp' 'main' '1.0.0'
        $result.source | Should -Be 'sqlite_exact_match'
        $result.version | Should -Be '1.0.0'
    }
    It 'should return null when no bucket provided' {
        $result = Get-HistoricalManifest 'testapp' $null '1.0.0'
        $result | Should -BeNullOrEmpty
    }
    It 'should return null when git history disabled' {
        Mock get_config { return $false }
        $result = Get-HistoricalManifest 'testapp' 'main' '1.0.0'
        $result | Should -BeNullOrEmpty
    }
}
Describe 'generate_user_manifest Enhanced Functionality' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-Manifest { return @('testapp', @{ version = '2.0.0' }, 'main', $null) }
        Mock manifest_path { return "C:\test\manifest.json" }
        Mock warn {}
        Mock info {}
        Mock abort { throw "aborted" }
        Mock Get-HistoricalManifest { return $null }
        Mock ensure { return "C:\temp" }
        Mock usermanifestsdir { return "C:\temp\manifests" }
        Mock Invoke-AutoUpdate { return "C:\temp\manifests\testapp.json" }
    }
    It 'should return existing manifest path when versions match' {
        Mock Get-Manifest { return @('testapp', @{ version = '1.5.0' }, 'main', $null) }
        $result = generate_user_manifest 'testapp' 'main' '1.5.0'
        $result | Should -Be "C:\test\manifest.json"
    }
    It 'should attempt historical manifest search when versions do not match' {
        Mock Get-HistoricalManifest {
            return @{
                path = "C:\temp\manifests\testapp.json"
                version = "1.0.0"
                source = "git_exact_match:abc123"
            }
        }
        Mock get_config {
            param($key)
            if ($key -eq 'USE_SQLITE_CACHE') { return $true }
            return $false
        }
        Mock warn {}
        $result = generate_user_manifest 'testapp' 'main' '1.0.0'
        $result | Should -Be "C:\temp\manifests\testapp.json"
        Should -Invoke -CommandName info -Times 1 -ParameterFilter {
            $args[0] -like "*Searching for version*in cache*"
        }
    }
    It 'should fallback to autoupdate when historical manifest not found' {
        Mock Get-HistoricalManifest { return $null }
        Mock Invoke-AutoUpdate { return "C:\temp\manifests\testapp.json" }
        Mock Get-Manifest { return @('testapp', @{ version = '2.0.0'; autoupdate = @{} }, 'main', $null) }
        Mock get_config { return $false }  # USE_SQLITE_CACHE disabled
        Mock Get-ScoopDBItem { return [PSCustomObject]@{ manifest = $null; Rows = @() } }
        $result = generate_user_manifest 'testapp' 'main' '1.0.0'
        Should -Invoke -CommandName warn -Times 1 -ParameterFilter {
            $args[0] -like "*No historical version found*"
        }
    }
}
