BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
}

Describe 'New-Shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
    }

    It "links a file onto the user's path" {
        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should-Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should-Throw
        { shim-test } | Should-Throw

        New-Shim "$working_dir\shim-test.ps1" $false 'shim-test'
        $null = & { Get-Command 'shim-test' -ea stop }
        $null = & { Get-Command 'shim-test.ps1' -ea stop }
        $null = & { Get-Command 'shim-test.cmd' -ea stop }
        shim-test | Should-Be 'Hello, world!'
    }

    It 'shims a file with a quote in its path' {
        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { shim-test } | Should-Throw

        New-Shim "$working_dir\user with 'quote\shim-test.ps1" $false 'shim-test'
        $null = & { Get-Command 'shim-test' -ea stop }
        shim-test | Should-Be 'Hello, world!'
    }

    AfterEach {
        Remove-Shim 'shim-test' $shimdir
    }
}

Describe 'Remove-Shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
    }

    It 'removes shim from path' {
        New-Shim "$working_dir\shim-test.ps1" $false 'shim-test'

        Remove-Shim 'shim-test' $shimdir

        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should-Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should-Throw
        { shim-test } | Should-Throw
    }
}

Describe 'Get-AppNameFromShim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
        Mock appsdir { $working_dir }
    }

    It 'returns empty string if file does not exist' {
        Get-AppNameFromShim 'non-existent-file' | Should-Be ''
    }

    It 'returns app name if file exists and is a shim to an app' {
        ensure "$working_dir/mockapp/current/"
        Write-Output '' | Out-File "$working_dir/mockapp/current/mockapp1.ps1"
        New-Shim "$working_dir/mockapp/current/mockapp1.ps1" $false 'shim-test1'
        $shim_path1 = (Get-Command 'shim-test1.ps1').Path
        Get-AppNameFromShim "$shim_path1" | Should-Be 'mockapp'
        ensure "$working_dir/mockapp/1.0.0/"
        Write-Output '' | Out-File "$working_dir/mockapp/1.0.0/mockapp2.ps1"
        New-Shim "$working_dir/mockapp/1.0.0/mockapp2.ps1" $false 'shim-test2'
        $shim_path2 = (Get-Command 'shim-test2.ps1').Path
        Get-AppNameFromShim "$shim_path2" | Should-Be 'mockapp'
    }

    It 'returns empty string if file exists and is not a shim' {
        Write-Output 'lorem ipsum' | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        Get-AppNameFromShim "$working_dir/mock-shim.ps1" | Should-Be ''
    }

    AfterAll {
        if (Get-Command 'shim-test1' -ErrorAction SilentlyContinue) {
            Remove-Shim 'shim-test1' $shimdir -ErrorAction SilentlyContinue
        }
        if (Get-Command 'shim-test2' -ErrorAction SilentlyContinue) {
            Remove-Shim 'shim-test2' $shimdir -ErrorAction SilentlyContinue
        }
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$working_dir/mockapp"
        Remove-Item -Force -ErrorAction SilentlyContinue "$working_dir/moch-shim.ps1"
    }
}

Describe 'Get-ShimExe' -Tag 'Scoop', 'Windows' {
    BeforeEach {
        Mock -CommandName warn
    }

    It 'returns the body matching the machine architecture' {
        $arch = switch (Get-SystemArchitecture) {
            'arm64' { 'arm64' }
            '64bit' { 'x64' }
            '32bit' { 'x86' }
        }
        Get-ShimExe | Should-BeLikeString "*\supporting\shims\$arch\shim.exe"
    }

    It 'bundles a body for every architecture' {
        'x64', 'x86', 'arm64' | ForEach-Object {
            Test-Path -LiteralPath (Join-Path $PSScriptRoot "..\supporting\shims\$_\shim.exe") | Should-Be $true
        }
    }

    It 'warns and falls back to the bundled shim for an unknown value' {
        Mock -CommandName get_config -MockWith { 'cs' } -ParameterFilter { $Name -eq 'SHIM' }
        Get-ShimExe | Should-BeLikeString '*\supporting\shims\*\shim.exe'
        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -like "*Unknown shim 'cs'*" }
    }

    It 'does not warn for the bundled shim' {
        Mock -CommandName get_config -MockWith { 'default' } -ParameterFilter { $Name -eq 'SHIM' }
        $null = Get-ShimExe
        Should-Invoke -CommandName warn -Times 0
    }
}

Describe 'Get-PEMachine' -Tag 'Scoop', 'Windows' {
    It 'returns machine type for a valid PE file' {
        $shim_path = Get-ShimExe
        $machine = Get-PEMachine $shim_path
        # Should be a known machine type (I386 (x86): 0x014c, amd64 (x64): 0x8664, arm64: 0xAA64)
        # https://learn.microsoft.com/en-us/windows/win32/sysinfo/image-file-machine-constants
        @(0x014c, 0x8664, 0xAA64) | Should-ContainCollection $machine
    }

    It 'returns 0 for a non-existent file' {
        Get-PEMachine 'C:\nonexistent\fake.exe' | Should-Be 0
    }

    It 'returns 0 for a non-PE file' {
        $working_dir = setup_working 'shim'
        Get-PEMachine "$working_dir\shim-test.ps1" | Should-Be 0
    }
}

Describe 'WoW64 path rewriting in shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $shimdir = shimdir
        # Bundled bodies are all x64, so report x86 to actually exercise the rewrite branch
        Mock -CommandName Get-PEMachine -MockWith { 0x014c }
    }

    It 'rewrites System32 to Sysnative in the shim file when the shim exe is x86 on x64 OS' {
        $target = "$env:SystemRoot\System32\notepad.exe"
        $rewrites = [System.Environment]::Is64BitOperatingSystem -and (Get-PEMachine (Get-ShimExe)) -eq 0x014c

        New-Shim $target $false 'wow64-test'

        $line = Get-Content "$shimdir\wow64-test.shim" | Select-Object -First 1
        if ($rewrites) {
            $line | Should-BeLikeString "*$env:SystemRoot\Sysnative\notepad.exe*"
        } else {
            $line | Should-BeLikeString "*$env:SystemRoot\System32\notepad.exe*"
        }

        # the 64-bit reader resolves the target back to the real System32 path either way
        Get-ShimTarget "$shimdir\wow64-test.shim" | Should-Be (Resolve-Path $target).Path
    }

    It 'does not rewrite paths outside System32 and SysWOW64' {
        $target = "$env:SystemRoot\explorer.exe"

        New-Shim $target $false 'wow64-test'

        $line = Get-Content "$shimdir\wow64-test.shim" | Select-Object -First 1
        $line | Should-BeLikeString "*$target*"
        Get-ShimTarget "$shimdir\wow64-test.shim" | Should-Be $target
    }

    It 'rewrites SysWOW64 to System32 in the shim file when the shim exe is x86 on x64 OS' {
        $wow = Join-Path ${env:SystemRoot} 'SysWOW64\notepad.exe'
        if (-not (Test-Path $wow)) {
            Set-ItResult -Skipped -Because 'SysWOW64 notepad not present'
        }
        $target = $wow
        $rewrites = [System.Environment]::Is64BitOperatingSystem -and (Get-PEMachine (Get-ShimExe)) -eq 0x014c

        New-Shim $target $false 'wow64-test'

        $line = Get-Content "$shimdir\wow64-test.shim" | Select-Object -First 1
        if ($rewrites) {
            # 64-bit reader sees the redirected (real) location via System32
            $line | Should-BeLikeString "*$env:SystemRoot\System32\notepad.exe*"
            Get-ShimTarget "$shimdir\wow64-test.shim" | Should-Be (Resolve-Path "$env:SystemRoot\System32\notepad.exe").Path
        } else {
            $line | Should-BeLikeString "*$target*"
            Get-ShimTarget "$shimdir\wow64-test.shim" | Should-Be (Resolve-Path $target).Path
        }
    }

    It 'does not fail on a shim file without a resolvable target' {
        Write-Output 'echo hi' | Out-File "$shimdir\broken.cmd" -Encoding ascii
        & { Get-ShimTarget "$shimdir\broken.cmd" }
        Get-ShimTarget "$shimdir\broken.cmd" | Should-BeNull

        Remove-Item "$shimdir\broken.cmd" -Force
    }

    AfterEach {
        Remove-Shim 'wow64-test' $shimdir
    }
}

Describe 'Get-ShimDefinition' -Tag 'Scoop' {
    It 'should use strings correctly' {
        $target, $name, $shimArgs = Get-ShimDefinition 'command.exe'
        $target | Should-Be 'command.exe'
        $name | Should-Be 'command'
        $shimArgs | Should-BeNull
    }

    It 'should expand the array correctly' {
        $target, $name, $shimArgs = Get-ShimDefinition @('foo.exe', 'bar')
        $target | Should-Be 'foo.exe'
        $name | Should-Be 'bar'
        $shimArgs | Should-BeNull

        $target, $name, $shimArgs = Get-ShimDefinition @('foo.exe', 'bar', '--test')
        $target | Should-Be 'foo.exe'
        $name | Should-Be 'bar'
        $shimArgs | Should-Be '--test'
    }
}
