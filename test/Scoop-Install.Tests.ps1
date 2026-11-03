BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\shortcuts.ps1"
    . "$PSScriptRoot\..\lib\psmodules.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\update.ps1"
}

Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should-Be 'foobar'
    }
}

Describe 'install_app' -Tag 'Scoop' {
    It 'should report the failure without aborting the batch' {
        Mock Get-Manifest { 'foo', [PSCustomObject]@{ version = '1.0' }, 'main', $null }
        Mock Get-SupportedArchitecture { $null }
        Mock error {}
        $failed = @{}

        install_app 'foo' '64bit' $false @{} $failed

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like "*doesn't support current architecture*" }
        $failed.Keys | Should-BeCollection -Count 1
        $failed['foo'] | Should-Be 'unsupported architecture'
    }

    It 'should skip an app whose dependency failed' {
        Mock Get-Manifest { 'bar', [PSCustomObject]@{ version = '1.0'; depends = @('foo') }, 'main', $null }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock error {}
        $failed = @{ 'foo' = 'download failed' }

        install_app 'bar' '64bit' $false @{} $failed

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*depends on foo*' }
        $failed['bar'] | Should-Be 'dependency failed: foo'
    }

    It 'should ignore a dependency that was only skipped' {
        $manifest = [PSCustomObject]@{ depends = @('foo', 'extras/bar') }
        $failed = @{ 'foo' = 'skipped: running process'; 'bar (global)' = 'download failed' }

        $deps = failed_deps $manifest $failed

        $deps | Should-BeCollection -Count 1
        @($deps)[0] | Should-Be 'bar'
    }
}

Describe 'link_app' -Tag 'Scoop' {
    BeforeAll {
        $current = '/fake/app/current'
        $version = '/fake/app/1.0'
        Mock New-ShimFromManifest {}
        Mock create_startmenu_shortcuts {}
        Mock install_psmodule {}
        Mock env_add_path {}
        Mock env_set {}
        Mock unlink_persist_data {}
        Mock persist_data {}
        Mock persist_permission {}
    }

    It 'should link through current and persist the version' {
        link_app ([PSCustomObject]@{}) $current $version '/fake/persist' $false '64bit'

        Should-Invoke New-ShimFromManifest -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke create_startmenu_shortcuts -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke install_psmodule -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke env_add_path -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke unlink_persist_data -Times 1 -ParameterFilter { $dir -eq $version }
        Should-Invoke persist_data -Times 1 -ParameterFilter { $original_dir -eq $version }
    }
}

Describe 'unlink_app' -Tag 'Scoop' {
    BeforeAll {
        $current = '/fake/app/current'
        $version = '/fake/app/1.0'
        Mock Remove-ShimFromManifest {}
        Mock rm_startmenu_shortcuts {}
        Mock unlink_current { '/fake/app/current' }
        Mock uninstall_psmodule {}
        Mock env_rm_path {}
        Mock env_rm {}
        Mock unlink_persist_data {}
    }

    It 'should unlink through current and persist the version' {
        unlink_app 'foo' ([PSCustomObject]@{}) $version '/fake/persist' $false '64bit'

        Should-Invoke uninstall_psmodule -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke env_rm_path -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke unlink_persist_data -Times 1 -ParameterFilter { $dir -eq $version }
    }
}

Describe 'remove_obsolete_wiring' -Tag 'Scoop' {
    BeforeAll {
        $old_path = Get-AbsolutePath '/fake/app/current/old'
        $ctx = [PSCustomObject]@{
            app          = 'foo'
            dir          = '/fake/app/1.0'
            persist_dir  = '/fake/persist'
            global       = $false
            architecture = '64bit'
        }
        Mock rm_startmenu_shortcuts {}
        Mock Remove-Path {}
        Mock Set-EnvVar {}
        Mock uninstall_psmodule {}
    }

    It 'should remove the entries the new manifest dropped' {
        $shimdir = Join-Path $TestDrive 'shims'
        New-Item -ItemType Directory -Path $shimdir -Force | Out-Null
        'path = "x"' | Set-Content (Join-Path $shimdir 'old.shim')
        'path = "y"' | Set-Content (Join-Path $shimdir 'kept.shim')
        Mock shimdir { $shimdir }

        $old = [PSCustomObject]@{ bin = @('old.exe', 'kept.exe', 'tool.exe') }
        $new = [PSCustomObject]@{ bin = @('kept.exe', 'tool.cmd') }

        remove_obsolete_wiring $ctx $old $new

        (Test-Path (Join-Path $shimdir 'old.shim')) | Should-BeFalse
        (Test-Path (Join-Path $shimdir 'kept.shim')) | Should-BeTrue
    }

    It 'should remove the dropped environment entries' {
        $old = [PSCustomObject]@{ env_set = [PSCustomObject]@{ OLD_VAR = 'x' } }
        $new = [PSCustomObject]@{ env_set = [PSCustomObject]@{ KEPT_VAR = 'y' } }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Set-EnvVar -Times 1 -ParameterFilter { $Name -eq 'OLD_VAR' }
        Should-Invoke Set-EnvVar -Times 0 -ParameterFilter { $Name -eq 'KEPT_VAR' }
    }

    It 'should remove the dropped paths' {
        $old = [PSCustomObject]@{ env_add_path = @('old', 'kept') }
        $new = [PSCustomObject]@{ env_add_path = @('kept') }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Remove-Path -ParameterFilter { $old_path -in $Path }
    }

    It 'should remove every old path without junctions' {
        Mock get_config { $true } -ParameterFilter { $Name -eq 'NO_JUNCTION' }
        $old = [PSCustomObject]@{ env_add_path = @('scripts') }
        $new = [PSCustomObject]@{ env_add_path = @('scripts') }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Remove-Path -ParameterFilter { (Get-AbsolutePath '/fake/app/1.0/scripts') -in $Path }
    }

    It 'should keep the module when the name did not change' {
        $old = [PSCustomObject]@{ psmodule = [PSCustomObject]@{ name = 'mod' } }
        $new = [PSCustomObject]@{ psmodule = [PSCustomObject]@{ name = 'mod' } }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke uninstall_psmodule -Times 0
    }
}

Describe 'restore_app' -Tag 'Scoop' {
    It 'should not fail when the links cannot be recreated' {
        $ctx = [PSCustomObject]@{
            app          = 'foo'
            dir          = '/fake/app/1.0'
            persist_dir  = '/fake/persist'
            global       = $false
            architecture = '64bit'
        }
        Mock installed_manifest { [PSCustomObject]@{ version = '1.0' } }
        Mock link_current { '/fake/app/current' }
        Mock link_app { throw 'cannot link' }

        restore_app $ctx ([PSCustomObject]@{ version = '1.0' }) '1.0' $null
    }
}

Describe 'show_failed_apps' -Tag 'Scoop' {
    It 'should list the failed apps with their reason' {
        Mock error {}

        show_failed_apps @{ 'foo' = 'reason one'; 'bar' = 'reason two' } 'update'

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*foo (reason one)*' -and $msg -like '*bar (reason two)*' }
    }

    It 'should report skipped apps separately' {
        Mock error {}
        Mock info {}

        $failed_count = show_failed_apps @{ 'foo' = 'skipped: running process'; 'bar' = 'reason' }

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*bar (reason)*' }
        Should-Invoke info -Times 1 -ParameterFilter { $msg -like '*foo (running process)*' }
        $failed_count | Should-Be 1
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
        $persist_dir = 'D:\persist\app'
    }

    It 'should concat the correct path' {
        Mock Add-Path {}
        Mock Remove-Path {}

        # adding
        env_add_path $manifest $testdir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }

        env_rm_path $manifest $testdir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Remove-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }
    }

    It 'should expand $persist_dir and $dir in env_add_path' {
        Mock Add-Path {}
        Mock Remove-Path {}

        $manifest = @{ 'env_add_path' = @('$persist_dir\bin', '$dir\lib') }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$persist_dir\bin" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\lib" }

        env_rm_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$persist_dir\bin" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\lib" }
    }

    It 'should expand %VAR% from the variables env_set defines' {
        Mock Add-Path {}
        Mock Remove-Path {}

        $manifest = [PSCustomObject]@{
            env_set      = [PSCustomObject]@{ 'COOP_TEST_DIR' = '$persist_dir\bin'; 'APP-HOME' = '$persist_dir\lib' }
            env_add_path = @('%COOP_TEST_DIR%', '%APP-HOME%', '%SOME_OTHER_VAR%', '%TEMP%\bin')
        }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\bin" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\lib" }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -contains '%SOME_OTHER_VAR%' }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -contains '%TEMP%\bin' }

        env_rm_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\bin" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\lib" }
    }

    It 'should not accept a %VAR% that points outside the app directories' {
        Mock Add-Path {}

        $manifest = [PSCustomObject]@{
            env_set      = [PSCustomObject]@{ 'COOP_TEST_OUT' = 'D:\elsewhere' }
            env_add_path = @('%COOP_TEST_OUT%')
        }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 0
    }

    It 'should keep the session %SCOOP_PATH% in sync with the stored value' {
        Mock get_config { $true } -ParameterFilter { $Name -eq 'USE_ISOLATED_PATH' }
        Mock Add-Path {}
        Mock Set-Item {}
        Mock Remove-Item {}

        $manifest = @{ 'env_add_path' = @('$dir\bin') }

        Mock Get-EnvVar { 'D:\apps\a\current' }
        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Set-Item -Times 1 -ParameterFilter { $Path -eq "env:$scoopPathEnvVar" -and $Value -eq 'D:\apps\a\current' }

        Mock Get-EnvVar { $null }
        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Item -Times 1 -ParameterFilter { $Path -eq "env:$scoopPathEnvVar" }
    }
}

Describe 'persist_def' -Tag 'Scoop' {
    It 'parses string correctly' {
        $source, $target = persist_def 'test'
        $source | Should-Be 'test'
        $target | Should-Be 'test'
    }

    It 'should handle sub-folder' {
        $source, $target = persist_def 'foo/bar'
        $source | Should-Be 'foo/bar'
        $target | Should-Be 'foo/bar'
    }

    It 'should handle arrays' {
        # both specified
        $source, $target = persist_def @('foo', 'bar')
        $source | Should-Be 'foo'
        $target | Should-Be 'bar'

        # only first specified
        $source, $target = persist_def @('foo')
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'

        # null value specified
        $source, $target = persist_def @('foo', $null)
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'
    }
}
