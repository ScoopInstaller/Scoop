BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
}

Describe 'shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
    }

    It "links a file onto the user's path" {
        { Get-Command 'shim-test' -ea stop } | Should -Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should -Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should -Throw
        { shim-test } | Should -Throw

        shim "$working_dir\shim-test.ps1" $false 'shim-test'
        { Get-Command 'shim-test' -ea stop } | Should -Not -Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should -Not -Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should -Not -Throw
        shim-test | Should -Be 'Hello, world!'
    }

    It 'shims a file with quote in path' {
        { Get-Command 'shim-test' -ea stop } | Should -Throw
        { shim-test } | Should -Throw

        shim "$working_dir\user with 'quote\shim-test.ps1" $false 'shim-test'
        { Get-Command 'shim-test' -ea stop } | Should -Not -Throw
        shim-test | Should -Be 'Hello, world!'
    }

    AfterEach {
        rm_shim 'shim-test' $shimdir
    }
}

Describe 'rm_shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
    }

    It 'removes shim from path' {
        shim "$working_dir\shim-test.ps1" $false 'shim-test'

        rm_shim 'shim-test' $shimdir

        { Get-Command 'shim-test' -ea stop } | Should -Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should -Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should -Throw
        { shim-test } | Should -Throw
    }
}

Describe 'get_app_name_from_shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
        Mock appsdir { $working_dir }
    }

    It 'returns empty string if file does not exist' {
        get_app_name_from_shim 'non-existent-file' | Should -Be ''
    }

    It 'returns app name if file exists and is a shim to an app' {
        ensure "$working_dir/mockapp/current/"
        Write-Output '' | Out-File "$working_dir/mockapp/current/mockapp1.ps1"
        shim "$working_dir/mockapp/current/mockapp1.ps1" $false 'shim-test1'
        $shim_path1 = (Get-Command 'shim-test1.ps1').Path
        get_app_name_from_shim "$shim_path1" | Should -Be 'mockapp'
        ensure "$working_dir/mockapp/1.0.0/"
        Write-Output '' | Out-File "$working_dir/mockapp/1.0.0/mockapp2.ps1"
        shim "$working_dir/mockapp/1.0.0/mockapp2.ps1" $false 'shim-test2'
        $shim_path2 = (Get-Command 'shim-test2.ps1').Path
        get_app_name_from_shim "$shim_path2" | Should -Be 'mockapp'
    }

    It 'returns empty string if file exists and is not a shim' {
        Write-Output 'lorem ipsum' | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        get_app_name_from_shim "$working_dir/mock-shim.ps1" | Should -Be ''
    }

    AfterAll {
        if (Get-Command 'shim-test1' -ErrorAction SilentlyContinue) {
            rm_shim 'shim-test1' $shimdir -ErrorAction SilentlyContinue
        }
        if (Get-Command 'shim-test2' -ErrorAction SilentlyContinue) {
            rm_shim 'shim-test2' $shimdir -ErrorAction SilentlyContinue
        }
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$working_dir/mockapp"
        Remove-Item -Force -ErrorAction SilentlyContinue "$working_dir/moch-shim.ps1"
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
