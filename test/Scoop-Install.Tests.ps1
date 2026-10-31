BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
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
