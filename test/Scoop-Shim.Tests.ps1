BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1" # 'arch_specific'

    $working_dir = setup_working 'shim'
    $shimdir = shimdir
    Add-Path $shimdir
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
        Get-PEMachine "$working_dir\shim-test.ps1" | Should-Be 0
    }
}

Describe 'Get-AppNameFromShim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
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

    It 'returns empty string if file exists but is not a shim' {
        Write-Output 'lorem ipsum' | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        Get-AppNameFromShim "$working_dir/mock-shim.ps1" | Should-Be ''
    }

    It 'reads a shim file whose name contains a wildcard character' {
        # -Path would read br[a]cket.shim as a character class and miss the file (#6592)
        $p = "$working_dir\br[a]cket.shim"
        [IO.File]::WriteAllText($p, "path = `"$working_dir\mockapp\current\mockapp.exe`"")

        Get-AppNameFromShim $p | Should-Be 'mockapp'
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

Describe 'Get-ShimTarget' -Tag 'Scoop', 'Windows' {
    It 'returns null for a shim file whose target is gone' {
        $broken = "$working_dir\broken.cmd"
        'echo hi' | Out-File $broken -Encoding ascii

        Get-ShimTarget $broken | Should-BeNull
    }
}

Describe 'New-Shim' -Tag 'Scoop', 'Windows' {
    BeforeEach {
        # abort exits the process, so it has to throw for the flow to stop
        Mock -CommandName abort -MockWith { throw $msg }
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

    It 'shims a file with quote in path' {
        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { shim-test } | Should-Throw

        New-Shim "$working_dir\user with 'quote\shim-test.ps1" $false 'shim-test'
        $null = & { Get-Command 'shim-test' -ea stop }
        shim-test | Should-Be 'Hello, world!'
    }

    It 'names the target it could not find' {
        { New-Shim "$working_dir\no-such.ps1" $false 'x' } | Should-Throw "*Can't shim 'no-such.ps1'*"
    }

    AfterEach {
        Remove-Shim 'shim-test' $shimdir
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
        Get-ShimExe 'default' | Should-BeLikeString "*\supporting\shims\$arch\shim.exe"
    }

    It 'bundles a body for every architecture' {
        'x64', 'x86', 'arm64' | ForEach-Object {
            Test-Path -LiteralPath (Join-Path $PSScriptRoot "..\supporting\shims\$_\shim.exe") | Should-Be $true
        }
    }

    It 'warns and falls back to the bundled shim for an unknown value' {
        Mock -CommandName get_config -MockWith { 'cs' } -ParameterFilter { $Name -eq 'SHIM' }
        Get-ShimExe | Should-BeLikeString '*\supporting\shims\*\shim.exe'
        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -like "*'cs' does not provide a shim*" }
    }

    It 'does not warn for the bundled shim' {
        Mock -CommandName get_config -MockWith { 'default' } -ParameterFilter { $Name -eq 'SHIM' }
        $null = Get-ShimExe
        Should-Invoke -CommandName warn -Times 0
    }

    It 'takes the body from an installed shim package' {
        $pkgdir = Join-Path $working_dir 'shim-pkg'
        New-Item -ItemType Directory -Force -Path (Join-Path $pkgdir 'current') | Out-Null
        'a body' | Out-File (Join-Path $pkgdir 'current\shim.exe') -NoNewline
        Mock -CommandName versiondir -MockWith { param($app, $version) if ($app -eq 'shim-pkg') { Join-Path $pkgdir 'current' } else { "$(versiondir $app $version)" } }

        Get-ShimExe 'shim-pkg' | Should-Be (Join-Path $pkgdir 'current\shim.exe')
        Should-Invoke -CommandName warn -Times 0
    }
}

Describe 'Set-ShimCopy' -Tag 'Scoop', 'Windows' {
    BeforeEach {
        # every case names its shims, so none of them sweeps the real shims directory
        New-Shim "$env:SystemRoot\System32\cmd.exe" $false 'copy-test'
        # make the copy recognisably not the body
        'clobbered' | Out-File "$shimdir\copy-test.exe"
    }

    AfterEach {
        Remove-Shim 'copy-test' $shimdir -ErrorAction SilentlyContinue
        Remove-Shim 'gui-test' $shimdir -ErrorAction SilentlyContinue
    }

    It 'replaces the exe of the shims it was given' {
        Set-ShimCopy (Get-ShimExe 'default') $false 'copy-test'
        (Get-FileHash -LiteralPath "$shimdir\copy-test.exe").Hash | Should-Be (Get-FileHash -LiteralPath (Get-ShimExe 'default')).Hash
    }

    It 'does not touch a shim it was not given' {
        Set-ShimCopy (Get-ShimExe 'default') $false 'not-installed'
        Get-Content -LiteralPath "$shimdir\copy-test.exe" -Raw | Should-BeLikeString '*clobbered*'
    }

    It 'skips a running shim and names it' {
        # isFileLocked is core's job; here a locked copy is what Set-ShimCopy has to cope with
        Mock -CommandName isFileLocked -MockWith { $true }
        Mock -CommandName warn
        Set-ShimCopy (Get-ShimExe 'default') $false 'copy-test'
        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -like '*copy-test*' }
        Get-Content -LiteralPath "$shimdir\copy-test.exe" -Raw | Should-BeLikeString '*clobbered*'
    }

    It 'restores the GUI flag the fresh copy lost' {
        New-Shim "$env:SystemRoot\System32\notepad.exe" $false 'gui-test'
        Get-PESubsystem "$shimdir\gui-test.exe" | Should-Be 2

        Set-ShimCopy (Get-ShimExe 'default') $false 'gui-test'
        Get-PESubsystem "$shimdir\gui-test.exe" | Should-Be 2
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

Describe 'New-ShimFromManifest' -Tag 'Scoop', 'Windows' {
    BeforeEach {
        # abort exits the process, so it has to throw for the flow to stop
        Mock -CommandName abort -MockWith { throw $msg }
    }

    It 'shims a target whose name contains a wildcard character' {
        [IO.File]::WriteAllText("$working_dir\br[a]cket.exe", 'not a real binary')

        New-ShimFromManifest @{ bin = @('br[a]cket.exe') } $working_dir $false '64bit'

        Test-Path -LiteralPath "$shimdir\br[a]cket.exe" | Should-Be $true
    }

    It 'names the manifest path instead of throwing a Get-Command error' {
        { New-ShimFromManifest @{ bin = @('no-such-target.exe') } $working_dir $false '64bit' } |
            Should-Throw "*Can't shim 'no-such-target.exe'*"
    }

    AfterEach {
        Remove-Shim 'br[a]cket' $shimdir -ErrorAction SilentlyContinue
    }
}

Describe 'Remove-Shim' -Tag 'Scoop', 'Windows' {
    It 'removes shim from path' {
        New-Shim "$working_dir\shim-test.ps1" $false 'shim-test'

        Remove-Shim 'shim-test' $shimdir

        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should-Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should-Throw
        { shim-test } | Should-Throw
    }

    It 'does not report an exe it never had' {
        # a shim set without an exe is what a mixed-arch manifest or an interrupted uninstall leaves (#6529)
        $dir = "$working_dir\no-exe"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'x' | Out-File "$dir\gone" -NoNewline
        'x' | Out-File "$dir\gone.shim" -NoNewline

        $removed = Remove-Shim 'gone' $dir 'gone'

        [bool]($removed -match 'gone\.exe') | Should-BeFalse
        Get-ChildItem $dir | Should-BeCollection -Count 0
    }
}

Describe 'Get-ShimInfo' -Tag 'Scoop', 'Windows' {
    It 'marks a shim hidden when nothing resolves its name' {
        # the command is gone when an app was uninstalled without its shim; that must not throw (#6206)
        $shimPath = "$working_dir\gone.shim"
        # utf8NoBOM is PowerShell 6+, and CI runs 5.1 too
        [IO.File]::WriteAllText($shimPath, 'path = "C:\nonexistent\gone.exe"')

        (Get-ShimInfo $shimPath).IsHidden | Should-BeTrue
    }
}

# a scenario, not a function: New-Shim writes the path and Get-ShimTarget reads it back
Describe 'WoW64 path rewriting' -Tag 'Scoop', 'Windows' {
    BeforeAll {
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

    AfterEach {
        Remove-Shim 'wow64-test' $shimdir
    }
}
