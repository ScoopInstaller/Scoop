BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1" # 'arch_specific'
}

Describe 'Get-PEMachine' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        # pin the switch input and the install root, so the machine's config cannot decide the verdict
        $repo_root = Join-Path $PSScriptRoot '..'
        Mock -CommandName get_config -MockWith { 'default' } -ParameterFilter { $Name -eq 'SHIM' }
        Mock -CommandName versiondir -MockWith { $repo_root } -ParameterFilter { $app -eq 'scoop' -and $version -eq 'current' }
    }

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

    It 'returns empty string if file exists but is not a shim' {
        Write-Output 'lorem ipsum' | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        Get-AppNameFromShim "$working_dir/mock-shim.ps1" | Should-Be ''
    }

    It 'reads a shim file whose name contains a wildcard character' {
        # -Path would read br[a]cket.shim as a character class and miss the file
        $p = "$working_dir\br[a]cket.shim"
        [IO.File]::WriteAllText($p, "path = `"$working_dir\mockapp\current\mockapp.exe`"")

        Get-AppNameFromShim $p | Should-Be 'mockapp'
    }

    AfterAll {
        if (Get-Command 'shim-test1' -ErrorAction SilentlyContinue) {
            Remove-Shim 'shim-test1' $shimdir
        }
        if (Get-Command 'shim-test2' -ErrorAction SilentlyContinue) {
            Remove-Shim 'shim-test2' $shimdir
        }
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$working_dir/mockapp"
        Remove-Item -Force -ErrorAction SilentlyContinue "$working_dir/mock-shim.ps1"
    }
}

Describe 'New-Shim' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        Add-Path $shimdir
    }

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

    It 'handles a shim name containing a wildcard character without raising an error' {
        $shimPath = "$shimdir\br[acket.shim"
        [IO.File]::WriteAllText($shimPath, '')

        $Error.Clear()
        Rename-ShimOnConflict $shimPath "$working_dir\shim-test.ps1"
        $Error.Count | Should-Be 0

        Remove-Item -LiteralPath $shimPath -Force
    }

    It 'names the target it could not find' {
        { New-Shim "$working_dir\no-such.ps1" $false 'x' } | Should-Throw "*Can't shim 'no-such.ps1'*"
    }

    AfterEach {
        Remove-Shim 'shim-test' $shimdir
    }
}

Describe 'Get-ShimTarget' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $targetDir = Join-Path $TestDrive 'shim-target'
        $null = [IO.Directory]::CreateDirectory($targetDir)
        $targetFile = Join-Path $targetDir 'br[a]cket-target.exe'
        [IO.File]::WriteAllText($targetFile, '')
    }

    It 'returns null for a shim file whose target is gone' {
        $broken = "$working_dir\broken.cmd"
        'echo hi' | Out-File $broken -Encoding ascii

        Get-ShimTarget $broken | Should-BeNull
    }

    It 'reads the target stored in a shim whose name contains a wildcard character' {
        $shimPath = Join-Path $targetDir 'br[a]cket.shim'
        [IO.File]::WriteAllText($shimPath, "path = $targetFile")

        Get-ShimTarget $shimPath | Should-Be $targetFile
    }

    It 'reads a target with non-ASCII characters from a shim file' {
        # the description is UTF-8, and Windows PowerShell 5.1 reads it as ANSI without the encoding
        $target = Join-Path $targetDir ("br$([char]0x00E4)cket-target.exe")
        [IO.File]::WriteAllText($target, '')
        $shimPath = Join-Path $targetDir 'nonascii.shim'
        [IO.File]::WriteAllText($shimPath, "path = `"$target`"", [Text.UTF8Encoding]::new($false))

        Get-ShimTarget $shimPath | Should-Be $target
    }
}

Describe 'Get-ShimExe' -Tag 'Scoop', 'Windows' {
    BeforeEach {
        Mock -CommandName warn
        Mock -CommandName get_config -MockWith { $false } -ParameterFilter { $Name -eq 'NO_JUNCTION' }
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
        $pkgdir = Join-Path $TestDrive 'shim-pkg'
        New-Item -ItemType Directory -Force -Path (Join-Path $pkgdir 'current') | Out-Null
        Copy-Item -LiteralPath (Get-ShimExe 'default') -Destination (Join-Path $pkgdir 'current\shim.exe')
        Mock -CommandName currentdir -MockWith { Join-Path $pkgdir 'current' }

        Get-ShimExe 'shim-pkg' | Should-Be (Join-Path $pkgdir 'current\shim.exe')
        Should-Invoke -CommandName warn -Times 0
    }

    It 'ignores a package body built for another architecture' {
        $arch = switch (Get-SystemArchitecture) {
            'arm64' { 'arm64' }
            '64bit' { 'x64' }
            '32bit' { 'x86' }
        }
        $other = 'x64', 'x86', 'arm64' | Where-Object { $_ -ne $arch } | Select-Object -First 1
        $pkgdir = Join-Path $TestDrive 'shim-pkg-other'
        New-Item -ItemType Directory -Force -Path (Join-Path $pkgdir 'current') | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\supporting\shims\$other\shim.exe") -Destination (Join-Path $pkgdir 'current\shim.exe')
        Mock -CommandName currentdir -MockWith { Join-Path $pkgdir 'current' }

        $bundled = Get-ShimExe 'default'
        Get-ShimExe 'shim-pkg-other' | Should-Be $bundled
        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -like "*'shim-pkg-other' provides a shim for another architecture*" }
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

Describe 'shim names with wildcard characters' -Tag 'Scoop', 'Windows' {

    It 'shims a target whose name contains a wildcard character' {
        Mock abort -MockWith { throw $msg }
        # the body lookup follows the machine's config, so pin it to the bundled body
        Mock Get-ShimExe { Join-Path $PSScriptRoot '..\supporting\shims\scoopcs\shim.exe' }
        # the shims of the machine and its path stay untouched
        $shimdir = Join-Path $TestDrive 'shims-wildcard'
        Mock shimdir { $shimdir }
        Mock Add-Path {}

        $dir = Join-Path $TestDrive 'br[a]cket-shim'
        $null = [IO.Directory]::CreateDirectory($dir)
        [IO.File]::WriteAllText("$dir\br[a]cket.exe", 'not a real binary')

        try {
            New-ShimFromManifest @{ bin = 'br[a]cket.exe' } $dir $false $null

            Test-Path -LiteralPath "$shimdir\br[a]cket.exe" | Should-Be $true
        } finally {
            Remove-Shim 'br[a]cket' $shimdir
        }
    }


    It 'removes a shim literally without touching a wildcard look-alike' {
        $shimdir = Join-Path $TestDrive 'shims'
        $null = [IO.Directory]::CreateDirectory($shimdir)
        [IO.File]::WriteAllText("$shimdir\br[a]cket.shim", '')
        [IO.File]::WriteAllText("$shimdir\bracket.shim", '')

        Remove-Shim 'br[a]cket' $shimdir

        Test-Path -LiteralPath "$shimdir\br[a]cket.shim" | Should-BeFalse
        Test-Path -LiteralPath "$shimdir\bracket.shim" | Should-BeTrue
    }

    It 'aborts with a friendly message when the shim target is not on PATH' {
        Mock New-Shim {}
        $aborted = @{}
        Mock abort { $aborted.Message = $msg; throw $msg }

        $dir = Join-Path $TestDrive 'missing'
        $null = [IO.Directory]::CreateDirectory($dir)

        # A caller with $ErrorActionPreference = 'Stop' must still reach the abort below, not a raw Get-Command error.
        { $ErrorActionPreference = 'Stop'; New-ShimFromManifest @{ bin = 'scoop-nonexistent-command' } $dir $false $null } |
            Should-Throw

        $aborted.Message | Should-Be "Can't shim 'scoop-nonexistent-command': File doesn't exist."
    }


    It 'resolves a bin target from $original_dir when it is not under $dir or on PATH' {
        Mock New-Shim {}
        Mock abort -MockWith { throw $msg }

        $dir = Join-Path $TestDrive 'linked-install'
        $originalDir = Join-Path $TestDrive 'original-install'
        $null = [IO.Directory]::CreateDirectory($dir)
        $null = [IO.Directory]::CreateDirectory($originalDir)
        [IO.File]::WriteAllText("$originalDir\scoop-bare-target.exe", '')

        # New-ShimFromManifest reads $original_dir from the caller's scope, as create_startmenu_shortcuts does.
        & {
            $original_dir = $originalDir
            New-ShimFromManifest @{ bin = 'scoop-bare-target.exe' } $dir $false $null
        }

        Should-Invoke -CommandName New-Shim -Times 1 -ParameterFilter { $Path -eq "$originalDir\scoop-bare-target.exe" }
    }


    It 'narrows the PATH lookup to applications and external scripts' {
        Mock New-Shim {}
        $seen = @{}
        Mock Get-CommandLiteral {
            $seen.CommandType = $CommandType
            [pscustomobject] @{ Source = "$TestDrive\bin-target.ps1" }
        }

        $dir = Join-Path $TestDrive 'narrowed-path'
        $null = [IO.Directory]::CreateDirectory($dir)

        New-ShimFromManifest @{ bin = 'bin-target.ps1' } $dir $false $null

        $types = "$($seen.CommandType)"
        ($types -match 'Application') | Should-BeTrue
        ($types -match 'ExternalScript') | Should-BeTrue
        Should-Invoke -CommandName New-Shim -Times 1 -ParameterFilter { $Path -eq "$TestDrive\bin-target.ps1" }
    }

    It 'picks one path when the bin name resolves to several commands' {
        $seen = @{}
        Mock New-Shim { $seen.Path = $Path }

        $pathDir = Join-Path $TestDrive 'multi-command'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        'scoop-multi-target.ps1', 'scoop-multi-target.cmd', 'scoop-multi-target.exe' | ForEach-Object {
            [IO.File]::WriteAllText("$pathDir\$_", '')
        }

        $oldPath = $env:PATH
        $env:PATH = "$pathDir;$env:PATH"
        try {
            # develop's expression against the same PATH, to prove the narrowed lookup picks the same command
            $expected = (Get-Command 'scoop-multi-target').Source

            $dir = Join-Path $TestDrive 'multi-command-install'
            $null = [IO.Directory]::CreateDirectory($dir)
            New-ShimFromManifest @{ bin = 'scoop-multi-target' } $dir $false $null

            $seen.Path -is [string] | Should-BeTrue
            $seen.Path | Should-Be $expected
            Should-Invoke -CommandName New-Shim -Times 1
        } finally {
            $env:PATH = $oldPath
        }
    }

    It 'resolves a bin target with wildcard characters from PATH to the literal file' {
        Mock New-Shim {}
        Mock abort -MockWith { throw $msg }

        $pathDir = Join-Path $TestDrive 'literal-path'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        'br[a]cket.exe', 'bracket.exe' | ForEach-Object { [IO.File]::WriteAllText("$pathDir\$_", '') }

        $oldPath = $env:PATH
        $env:PATH = "$pathDir;$env:PATH"
        try {
            $dir = Join-Path $TestDrive 'literal-path-install'
            $null = [IO.Directory]::CreateDirectory($dir)
            New-ShimFromManifest @{ bin = 'br[a]cket.exe' } $dir $false $null
        } finally {
            $env:PATH = $oldPath
        }

        Should-Invoke -CommandName New-Shim -Times 1 -ParameterFilter { $Path -eq "$pathDir\br[a]cket.exe" }
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

    It 'does not report an exe it never had' {
        # a shim set without an exe is what a mixed-arch manifest or an interrupted uninstall leaves
        $dir = "$working_dir\no-exe"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'x' | Out-File "$dir\gone" -NoNewline
        'x' | Out-File "$dir\gone.shim" -NoNewline

        $removed = Remove-Shim 'gone' $dir 'gone'

        [bool]($removed -match 'gone\.exe') | Should-BeFalse
        Get-ChildItem $dir | Should-BeCollection -Count 0
    }

    It 'brings back the version it took over' {
        # two apps shim the same name; Rename-ShimOnConflict kept the first one as a backup
        $dir = "$working_dir\alt"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'second' | Out-File "$dir\dupe.shim" -NoNewline
        'second' | Out-File "$dir\dupe.cmd" -NoNewline
        'second' | Out-File "$dir\dupe" -NoNewline
        'second' | Out-File "$dir\dupe.ps1" -NoNewline
        'first' | Out-File "$dir\dupe.shim.first" -NoNewline
        'first' | Out-File "$dir\dupe.cmd.first" -NoNewline
        'plain-first' | Out-File "$dir\dupe.first" -NoNewline
        'script-first' | Out-File "$dir\dupe.ps1.first" -NoNewline
        # the newest backup belongs to a wrapper, so no other wrapper may take it over
        [IO.File]::SetLastWriteTimeUtc("$dir\dupe.ps1.first", (Get-Date).ToUniversalTime())

        Remove-Shim 'dupe' $dir | Out-Null

        # the exe is not per-app, so it is left alone; every wrapper gets its own backup back
        [IO.File]::ReadAllText("$dir\dupe.shim") | Should-Be 'first'
        [IO.File]::ReadAllText("$dir\dupe.cmd") | Should-Be 'first'
        [IO.File]::ReadAllText("$dir\dupe") | Should-Be 'plain-first'
        [IO.File]::ReadAllText("$dir\dupe.ps1") | Should-Be 'script-first'
    }

    It 'brings back the version it took over from an app name with dots' {
        # the backup keeps the whole app name, so the match must not stop at the last dot
        $dir = "$working_dir\dotted"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'second' | Out-File "$dir\dupe.shim" -NoNewline
        'first' | Out-File "$dir\dupe.shim.foo.bar" -NoNewline
        'x' | Out-File "$dir\dupe.exe" -NoNewline

        Remove-Shim 'dupe' $dir | Out-Null

        [IO.File]::ReadAllText("$dir\dupe.shim") | Should-Be 'first'
        Test-Path -LiteralPath "$dir\dupe.exe" | Should-Be $true
    }

    It 'does not mistake the exe for a saved alternative' {
        # the exe has no app of its own, so it is a copy to remove, not a version to restore
        $dir = "$working_dir\no-alt"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'x' | Out-File "$dir\dupe.shim" -NoNewline
        'x' | Out-File "$dir\dupe.exe" -NoNewline

        Remove-Shim 'dupe' $dir | Out-Null

        Get-ChildItem $dir | Should-BeCollection -Count 0
    }
}

# a scenario, not a function: New-Shim writes the path and Get-ShimTarget reads it back
Describe 'shim target paths' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $shimdir = shimdir
    }

    It 'stores System32 as it was named' {
        $target = "$env:SystemRoot\System32\notepad.exe"

        New-Shim $target $false 'sysdir-test'

        (Get-Content "$shimdir\sysdir-test.shim" | Select-Object -First 1) |
            Should-BeLikeString "*$env:SystemRoot\System32\notepad.exe*"
    }

    It 'stores SysWOW64 as it was named, so naming it selects the 32-bit program' {
        $target = Join-Path $env:SystemRoot 'SysWOW64\notepad.exe'
        if (-not (Test-Path $target)) {
            Set-ItResult -Skipped -Because 'SysWOW64 notepad not present'
        }

        New-Shim $target $false 'wow64-test'

        (Get-Content "$shimdir\wow64-test.shim" | Select-Object -First 1) |
            Should-BeLikeString "*$env:SystemRoot\SysWOW64\notepad.exe*"
    }

    It 'does not fail on a shim file without a resolvable target' {
        Write-Output 'echo hi' | Out-File "$shimdir\broken.cmd" -Encoding ascii
        & { Get-ShimTarget "$shimdir\broken.cmd" }
        Get-ShimTarget "$shimdir\broken.cmd" | Should-BeNull

        Remove-Item "$shimdir\broken.cmd" -Force
    }

    AfterEach {
        Remove-Shim 'sysdir-test' $shimdir
        Remove-Shim 'wow64-test' $shimdir
    }
}

Describe 'Get-ShimInfo' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'shim'
    }

    It 'marks a shim hidden when nothing resolves its name' {
        # the command is gone when an app was uninstalled without its shim; that must not throw
        $shimPath = "$working_dir\gone.shim"
        # utf8NoBOM is PowerShell 6+, and CI runs 5.1 too
        [IO.File]::WriteAllText($shimPath, 'path = "C:\nonexistent\gone.exe"')

        (Get-ShimInfo $shimPath).IsHidden | Should-BeTrue
    }

    It 'lists the alternatives of a shim whose app name has dots' {
        $shimPath = "$working_dir\dupe.shim"
        [IO.File]::WriteAllText($shimPath, 'path = "C:\nonexistent\dupe.exe"')
        [IO.File]::WriteAllText("$working_dir\dupe.shim.foo.bar", 'path = "C:\nonexistent\dupe.exe"')

        (Get-ShimInfo $shimPath).Alternatives | Should-Be 'External bar'
    }
}

