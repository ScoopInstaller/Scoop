BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
}

Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should -Be 'foobar'
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

Describe 'install_app transactional staging and rollback' -Tag 'Scoop' {
    BeforeAll {
        $testDir = Join-Path $PSScriptRoot 'install-test-directory'
        if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
        $app = 'testapp'
        $global = $false
        $suggested = @{}
    }

    AfterAll {
        if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'stages files and promotes to target on success' {
        Mock appsdir { "$testDir\apps" }
        Mock Get-Manifest { 'testapp', [pscustomobject]@{ version = '1.0.0' }, $null, 'http://url' }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock get_config { $false }
        Mock Invoke-ScoopDownload { 'app.zip' }
        Mock Invoke-Extraction {
            param($Path, $Name, $Manifest, $ProcessorArchitecture)
            Set-Content (Join-Path $Path 'app.exe') 'content'
        }
        Mock Invoke-HookScript {}
        Mock Invoke-Installer {}
        Mock ensure_install_dir_not_in_path {}
        Mock link_current { param($dir) $dir }
        Mock create_shims {}
        Mock create_startmenu_shortcuts {}
        Mock install_psmodule {}
        Mock env_add_path {}
        Mock env_set {}
        Mock persist_data {}
        Mock persist_permission {}
        Mock save_installed_manifest {}
        Mock save_install_info {}
        Mock show_notes {}
        Mock success {}

        install_app $app '64bit' $global $suggested

        $targetDir = "$testDir\apps\$app\1.0.0"
        $stagingDir = "$testDir\apps\$app\_scoop_staging_1.0.0"

        Test-Path (Join-Path $targetDir 'app.exe') | Should -Be $true
        Test-Path $stagingDir | Should -Be $false
    }

    It 'cleans up staging on failure without leaving target' {
        Mock appsdir { "$testDir\apps" }
        Mock Get-Manifest { 'testapp', [pscustomobject]@{ version = '2.0.0' }, $null, 'http://url' }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock get_config { $false }
        Mock Invoke-ScoopDownload { 'app.zip' }
        Mock Invoke-Extraction {
            param($Path, $Name, $Manifest, $ProcessorArchitecture)
            throw 'Extraction failed'
        }

        { install_app $app '64bit' $global $suggested } | Should -Throw

        $targetDir = "$testDir\apps\$app\2.0.0"
        $stagingDir = "$testDir\apps\$app\_scoop_staging_2.0.0"

        Test-Path $targetDir | Should -Be $false
        Test-Path $stagingDir | Should -Be $false
    }

    It 'restores backup on failure after swap' {
        Mock appsdir { "$testDir\apps" }
        $targetDir = "$testDir\apps\$app\3.0.0"
        $null = ensure $targetDir
        Set-Content (Join-Path $targetDir 'pre_existing.txt') 'original'

        Mock Get-Manifest { 'testapp', [pscustomobject]@{ version = '3.0.0' }, $null, 'http://url' }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock get_config { $false }
        Mock Invoke-ScoopDownload { 'app.zip' }
        Mock Invoke-Extraction {
            param($Path, $Name, $Manifest, $ProcessorArchitecture)
            Set-Content (Join-Path $Path 'new.exe') 'new'
        }
        Mock Invoke-HookScript {}
        Mock Invoke-Installer { throw 'Post-swap installer failure' }

        { install_app $app '64bit' $global $suggested } | Should -Throw

        $backupDir = "$testDir\apps\$app\_scoop_old_3.0.0"
        $stagingDir = "$testDir\apps\$app\_scoop_staging_3.0.0"

        Test-Path (Join-Path $targetDir 'pre_existing.txt') | Should -Be $true
        Test-Path $backupDir | Should -Be $false
        Test-Path $stagingDir | Should -Be $false
    }

    It 'recovers stranded backup before starting new install' {
        Mock appsdir { "$testDir\apps" }
        $appDir = "$testDir\apps\$app"
        $backupDir = "$appDir\_scoop_old_4.0.0"
        $null = ensure $backupDir
        Set-Content (Join-Path $backupDir 'recovered.txt') 'saved'

        Mock Get-Manifest { 'testapp', [pscustomobject]@{ version = '4.0.0' }, $null, 'http://url' }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock get_config { $false }
        Mock Invoke-ScoopDownload { 'app.zip' }
        Mock Invoke-Extraction {
            param($Path, $Name, $Manifest, $ProcessorArchitecture)
            Set-Content (Join-Path $Path 'app.exe') 'installed'
        }
        Mock Invoke-HookScript {}
        Mock Invoke-Installer {}
        Mock ensure_install_dir_not_in_path {}
        Mock link_current { param($dir) $dir }
        Mock create_shims {}
        Mock create_startmenu_shortcuts {}
        Mock install_psmodule {}
        Mock env_add_path {}
        Mock env_set {}
        Mock persist_data {}
        Mock persist_permission {}
        Mock save_installed_manifest {}
        Mock save_install_info {}
        Mock show_notes {}
        Mock success {}

        install_app $app '64bit' $global $suggested

        $targetDir = "$appDir\4.0.0"
        Test-Path (Join-Path $targetDir 'app.exe') | Should -Be $true
        Test-Path $backupDir | Should -Be $false
    }
}


