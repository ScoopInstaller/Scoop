BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\restart_manager.ps1"
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

Describe 'check_running_process' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $global = $false
    }

    It 'returns correct hashtable when forcekill is enabled with RM-detected service' {
        Mock install_info { return @{ forcekill = $true; forcekill_services = @('manual_svc') } }
        Mock get_config { return $false }
        Mock versiondir { return 'C:\test\app\current' }
        Mock Convert-Path { return 'C:\test\app\current' }
        Mock Get-LockingProcesses {
            return @(
                [PSCustomObject]@{ Id = 123; Name = 'app'; AppName = 'app'; Path = 'C:\test\app\current\app.exe'; ApplicationType = 'Console'; ServiceName = ''; Restartable = $false; MainWindowHandle = [IntPtr]::Zero },
                [PSCustomObject]@{ Id = 456; Name = 'app_svc'; AppName = 'app_svc'; Path = 'C:\test\app\current\app.exe'; ApplicationType = 'Service'; ServiceName = 'rm_svc'; Restartable = $true; MainWindowHandle = [IntPtr]::Zero }
            )
        }

        $result = check_running_process 'testapp' $global
        $result.Blocked | Should -BeFalse
        $result.Forcekill | Should -BeTrue
        $result.ServicesToStop.Count | Should -Be 2
        $result.ServicesToStop | Should -Contain 'rm_svc'
        $result.ServicesToStop | Should -Contain 'manual_svc'
        $result.RunningProcesses.Count | Should -Be 2
    }

    It 'blocks when processes are running and forcekill is disabled' {
        Mock install_info { return $null }
        Mock get_config { return $false }
        Mock versiondir { return 'C:\test\app\current' }
        Mock Convert-Path { return 'C:\test\app\current' }
        Mock Get-LockingProcesses {
            return @(
                [PSCustomObject]@{ Id = 123; Name = 'app'; AppName = 'app'; Path = 'C:\test\app\current\app.exe'; ApplicationType = 'Console'; ServiceName = ''; Restartable = $false; MainWindowHandle = [IntPtr]::Zero }
            )
        }

        $result = check_running_process 'testapp' $global
        $result.Blocked | Should -BeTrue
        $result.Forcekill | Should -BeFalse
        $result.RunningProcesses.Count | Should -Be 1
    }

    It 'filters out Explorer and Critical processes' {
        Mock install_info { return $null }
        Mock get_config { return $false }
        Mock versiondir { return 'C:\test\app\current' }
        Mock Convert-Path { return 'C:\test\app\current' }
        Mock Get-LockingProcesses {
            return @(
                [PSCustomObject]@{ Id = 100; Name = 'app'; AppName = 'app'; Path = 'C:\test\app\current\app.exe'; ApplicationType = 'Console'; ServiceName = ''; Restartable = $false; MainWindowHandle = [IntPtr]::Zero },
                [PSCustomObject]@{ Id = 200; Name = 'explorer'; AppName = 'Windows Explorer'; Path = 'C:\WINDOWS\Explorer.EXE'; ApplicationType = 'Explorer'; ServiceName = ''; Restartable = $true; MainWindowHandle = [IntPtr]::Zero },
                [PSCustomObject]@{ Id = 300; Name = 'csrss'; AppName = 'csrss'; Path = 'C:\WINDOWS\system32\csrss.exe'; ApplicationType = 'Critical'; ServiceName = ''; Restartable = $false; MainWindowHandle = [IntPtr]::Zero }
            )
        }

        $result = check_running_process 'testapp' $global
        $result.RunningProcesses.Count | Should -Be 1
        $result.RunningProcesses[0].Id | Should -Be 100
    }
}

Describe 'stop_running_process' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        Mock warn {}
        Mock error {}
        Mock Write-Host {}
    }

    It 'kills background process and adds to returned restart list' {
        $test_result = @{
            Blocked          = $false
            Forcekill        = $true
            App              = 'testapp'
            RunningProcesses = @(
                [PSCustomObject]@{ Path = 'C:\test\app\current\app.exe'; Id = 123; Name = 'app'; ApplicationType = 'Console'; MainWindowHandle = [IntPtr]::Zero }
            )
            ServicesToStop   = @()
            ProcessDir       = 'C:\test\app\current'
        }

        Mock Stop-Process {}
        Mock Get-LockingProcesses { return @() } # No processes still locking after kill

        $result = stop_running_process $test_result

        $result.Blocked | Should -BeFalse
        $result.ProcessesToRestart.Count | Should -Be 1
        $result.ProcessesToRestart[0] | Should -Be 'C:\test\app\current\app.exe'

        Should -Invoke -CommandName Stop-Process -Times 1 -ParameterFilter { $Id -eq 123 }
    }

    It 'kills MainWindow process but does NOT add to restart list' {
        $test_result = @{
            Blocked          = $false
            Forcekill        = $true
            App              = 'testapp'
            RunningProcesses = @(
                [PSCustomObject]@{ Path = 'C:\test\app\current\app.exe'; Id = 124; Name = 'app'; ApplicationType = 'MainWindow'; MainWindowHandle = [IntPtr]::Zero }
            )
            ServicesToStop   = @()
            ProcessDir       = 'C:\test\app\current'
        }

        Mock Stop-Process {}
        Mock Get-LockingProcesses { return @() }

        $result = stop_running_process $test_result

        $result.Blocked | Should -BeFalse
        $result.ProcessesToRestart.Count | Should -Be 0
        Should -Invoke -CommandName Stop-Process -Times 1 -ParameterFilter { $Id -eq 124 }
    }

    It 'does not try to kill Service-type processes (handled separately)' {
        $test_result = @{
            Blocked          = $false
            Forcekill        = $true
            App              = 'testapp'
            RunningProcesses = @(
                [PSCustomObject]@{ Path = 'C:\test\app\current\svc.exe'; Id = 500; Name = 'app_svc'; ApplicationType = 'Service'; MainWindowHandle = [IntPtr]::Zero }
            )
            ServicesToStop   = @('test_svc')
            ProcessDir       = 'C:\test\app\current'
        }

        $Script:mock_svc_status = 'Running'
        Mock is_admin { return $true }
        Mock Stop-Process {}
        Mock Get-LockingProcesses { return @() }
        Mock Get-Service { return [PSCustomObject]@{ Status = $Script:mock_svc_status } } -ParameterFilter { $Name -eq 'test_svc' }
        Mock Stop-Service { $Script:mock_svc_status = 'Stopped' }

        $result = stop_running_process $test_result

        # Service-type processes should not be killed via Stop-Process
        Should -Invoke -CommandName Stop-Process -Times 0
        # But the service should be stopped via Stop-Service
        Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq 'test_svc' }
        $result.ServicesToRestart.Count | Should -Be 1
        $result.ServicesToRestart[0] | Should -Be 'test_svc'
    }

    It 'stops services when admin and adds them to restart list' {
        $test_result = @{
            Blocked          = $false
            Forcekill        = $true
            App              = 'testapp'
            RunningProcesses = @()
            ServicesToStop   = @('test_svc')
            ProcessDir       = 'C:\test\app\current'
        }

        $Script:mock_svc_status = 'Running'
        Mock is_admin { return $true }
        Mock Get-Service { return [PSCustomObject]@{ Status = $Script:mock_svc_status } } -ParameterFilter { $Name -eq 'test_svc' }
        Mock Stop-Service { $Script:mock_svc_status = 'Stopped' }

        $result = stop_running_process $test_result

        $result.Blocked | Should -BeFalse
        $result.ServicesToRestart.Count | Should -Be 1
        $result.ServicesToRestart[0] | Should -Be 'test_svc'

        Should -Invoke -CommandName Stop-Service -Times 1 -ParameterFilter { $Name -eq 'test_svc' }
    }

    It 'blocks service forcekill if not admin' {
        $test_result = @{
            Blocked          = $false
            Forcekill        = $true
            App              = 'testapp'
            RunningProcesses = @()
            ServicesToStop   = @('test_svc')
            ProcessDir       = 'C:\test\app\current'
        }

        Mock is_admin { return $false }

        $result = stop_running_process $test_result

        $result.Blocked | Should -BeTrue
    }
}

