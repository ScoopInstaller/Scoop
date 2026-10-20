BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
}

Describe 'Get-AppFilePath' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'is_directory'
        Mock currentdir { 'local' } -Verifiable -ParameterFilter { $global -eq $false }
        Mock currentdir { 'global' } -Verifiable -ParameterFilter { $global -eq $true }
    }

    It 'should return locally installed program' {
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq 'local\i_am_a_file.txt' }
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq 'global\i_am_a_file.txt' }
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should-Be 'local\i_am_a_file.txt'
    }

    It 'should return globally installed program' {
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq 'local\i_am_a_file.txt' }
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq 'global\i_am_a_file.txt' }
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should-Be 'global\i_am_a_file.txt'
    }

    It 'should return null if program is not installed' {
        Get-AppFilePath -App 'is_directory' -File 'i_do_not_exist' | Should-BeNull
    }

    It 'should throw if parameter is wrong or missing' {
        { Get-AppFilePath -App 'is_directory' -File } | Should-Throw
        { Get-AppFilePath -App -File 'i_am_a_file.txt' } | Should-Throw
        { Get-AppFilePath -App -File } | Should-Throw
    }
}

Describe 'Get-HelperPath' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'is_directory'
    }
    It 'should return path if program is installed' {
        Mock Get-AppFilePath { '7zip\current\7z.exe' }
        Get-HelperPath -Helper 7zip | Should-Be '7zip\current\7z.exe'
    }

    It 'should return null if program is not installed' {
        Mock Get-AppFilePath { $null }
        Get-HelperPath -Helper 7zip | Should-BeNull
    }

    It 'should throw if parameter is wrong or missing' {
        { Get-HelperPath -Helper } | Should-Throw
        { Get-HelperPath -Helper Wrong } | Should-Throw
    }
}


Describe 'Test-HelperInstalled' -Tag 'Scoop' {
    It 'should return true if program is installed' {
        Mock Get-HelperPath { '7z.exe' }
        Test-HelperInstalled -Helper 7zip | Should-BeTrue
    }

    It 'should return false if program is not installed' {
        Mock Get-HelperPath { $null }
        Test-HelperInstalled -Helper 7zip | Should-BeFalse
    }

    It 'should throw if parameter is wrong or missing' {
        { Test-HelperInstalled -Helper } | Should-Throw
        { Test-HelperInstalled -Helper Wrong } | Should-Throw
    }
}

Describe 'Test-CommandAvailable' -Tag 'Scoop' {
    It 'should return true if command exists' {
        Test-CommandAvailable 'Write-Host' | Should-BeTrue
    }

    It "should return false if command doesn't exist" {
        Test-CommandAvailable 'Write-ThisWillProbablyNotExist' | Should-BeFalse
    }

    It 'should throw if parameter is wrong or missing' {
        { Test-CommandAvailable } | Should-Throw
    }
}


Describe 'is_directory' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'is_directory'
    }

    It 'is_directory recognize directories' {
        is_directory "$working_dir\i_am_a_directory" | Should-Be $true
    }
    It 'is_directory recognize files' {
        is_directory "$working_dir\i_am_a_file.txt" | Should-Be $false
    }

    It 'is_directory is falsey on unknown path' {
        is_directory "$working_dir\i_do_not_exist" | Should-Be $false
    }
}

Describe 'movedir' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $working_dir = setup_working 'movedir'
        $extract_dir = 'subdir'
        $extract_to = $null
    }

    It 'moves directories with no spaces in path' {
        $dir = "$working_dir\user"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        (Get-Content "$dir\test.txt" -Raw) | Should-MatchString 'this is the one'
        Test-Path "$dir\_tmp\$extract_dir" | Should-BeFalse
    }

    It 'moves directories with spaces in path' {
        $dir = "$working_dir\user with space"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        (Get-Content "$dir\test.txt" -Raw) | Should-MatchString 'this is the one'
        Test-Path "$dir\_tmp\$extract_dir" | Should-BeFalse

        # test trailing \ in from dir
        movedir "$dir\_tmp\$null" "$dir\another"
        (Get-Content "$dir\another\test.txt" -Raw) | Should-MatchString 'testing'
        Test-Path "$dir\_tmp" | Should-BeFalse
    }

    It 'moves directories with quotes in path' {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        (Get-Content "$dir\test.txt" -Raw) | Should-MatchString 'this is the one'
        Test-Path "$dir\_tmp\$extract_dir" | Should-BeFalse
    }
}

Describe 'shim' -Tag 'Scoop', 'Windows' {
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

        shim "$working_dir\shim-test.ps1" $false 'shim-test'
        $null = & { Get-Command 'shim-test' -ea stop }
        $null = & { Get-Command 'shim-test.ps1' -ea stop }
        $null = & { Get-Command 'shim-test.cmd' -ea stop }
        shim-test | Should-Be 'Hello, world!'
    }

    It 'shims a file with quote in path' {
        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { shim-test } | Should-Throw

        shim "$working_dir\user with 'quote\shim-test.ps1" $false 'shim-test'
        $null = & { Get-Command 'shim-test' -ea stop }
        shim-test | Should-Be 'Hello, world!'
    }

    It 'handles a shim name containing a wildcard character without raising an error' {
        $shimPath = "$shimdir\br[acket.shim"
        [IO.File]::WriteAllText($shimPath, '')

        $Error.Clear()
        warn_on_overwrite $shimPath "$working_dir\shim-test.ps1"
        $Error.Count | Should-Be 0

        Remove-Item -LiteralPath $shimPath -Force
    }

    It 'names the target it could not find' {
        { shim "$working_dir\no-such.ps1" $false 'x' } | Should-Throw "*Can't shim 'no-such.ps1'*"
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

        { Get-Command 'shim-test' -ea stop } | Should-Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should-Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should-Throw
        { shim-test } | Should-Throw
    }

    It 'brings back the version it took over' {
        # two apps shim the same name; warn_on_overwrite kept the first one as a backup
        $dir = "$working_dir\alt"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'second' | Out-File "$dir\dupe.shim" -NoNewline
        'second' | Out-File "$dir\dupe.cmd" -NoNewline
        'first' | Out-File "$dir\dupe.shim.first" -NoNewline
        'first' | Out-File "$dir\dupe.cmd.first" -NoNewline

        rm_shim 'dupe' $dir | Out-Null

        # the exe is not per-app, so it is left alone; the backup becomes the default again
        [IO.File]::ReadAllText("$dir\dupe.shim") | Should-Be 'first'
        [IO.File]::ReadAllText("$dir\dupe.cmd") | Should-Be 'first'
    }

    It 'does not mistake the exe for a saved alternative' {
        # the exe has no app of its own, so it is a copy to remove, not a version to restore
        $dir = "$working_dir\no-alt"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        'x' | Out-File "$dir\dupe.shim" -NoNewline
        'x' | Out-File "$dir\dupe.exe" -NoNewline

        rm_shim 'dupe' $dir | Out-Null

        Get-ChildItem $dir | Should-BeCollection -Count 0
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
        get_app_name_from_shim 'non-existent-file' | Should-Be ''
    }

    It 'returns app name if file exists and is a shim to an app' {
        ensure "$working_dir/mockapp/current/"
        Write-Output '' | Out-File "$working_dir/mockapp/current/mockapp1.ps1"
        shim "$working_dir/mockapp/current/mockapp1.ps1" $false 'shim-test1'
        $shim_path1 = (Get-Command 'shim-test1.ps1').Path
        get_app_name_from_shim "$shim_path1" | Should-Be 'mockapp'
        ensure "$working_dir/mockapp/1.0.0/"
        Write-Output '' | Out-File "$working_dir/mockapp/1.0.0/mockapp2.ps1"
        shim "$working_dir/mockapp/1.0.0/mockapp2.ps1" $false 'shim-test2'
        $shim_path2 = (Get-Command 'shim-test2.ps1').Path
        get_app_name_from_shim "$shim_path2" | Should-Be 'mockapp'
    }

    It 'returns empty string if file exists and is not a shim' {
        Write-Output 'lorem ipsum' | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        get_app_name_from_shim "$working_dir/mock-shim.ps1" | Should-Be ''
    }

    It 'reads a shim file whose name contains a wildcard character' {
        # -Path would read br[a]cket.shim as a character class and miss the file
        $p = "$working_dir\br[a]cket.shim"
        [IO.File]::WriteAllText($p, "path = `"$working_dir\mockapp\current\mockapp.exe`"")

        get_app_name_from_shim $p | Should-Be 'mockapp'
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

Describe 'cache_path' -Tag 'Scoop' {
    It 'returns the correct cache path for a given input' {
        $url = 'https://example.com/git.zip'
        $ret = cache_path 'git' '2.44.0' $url
        $inputStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($url))
        $sha = (Get-FileHash -Algorithm SHA256 -InputStream $inputStream).Hash.ToLower().Substring(0, 7)
        $ret | Should-Be "$cachedir\git#2.44.0#$sha.zip"
    }

    # # NOTE: Remove this 6 months after the feature ships.
    It 'returns the old format cache path for a given input' {
        Mock Test-Path { $true }
        $ret = cache_path 'git' '2.44.0' 'https://example.com/git.zip'
        $ret | Should-Be "$cachedir\git#2.44.0#https_example.com_git.zip"
    }
}

Describe 'Get-RelativePath' -Tag 'Scoop' {
    It 'returns relative path for child path' {
        $from = 'C:\root\bucket'
        $to = 'C:\root\bucket\foo\bar.json'
        Get-RelativePath $from $to | Should-Be 'foo\bar.json'
    }
    It 'returns original when different drive/scheme' {
        $from = 'C:\root\bucket'
        $to = 'D:\other\file.json'
        Get-RelativePath $from $to | Should-Be $to
    }
    It 'handles paths containing characters that break [System.Uri]' {
        $from = 'C:\b#ucket'
        $to = 'C:\b#ucket\foo.json'
        Get-RelativePath $from $to | Should-Be 'foo.json'
    }
    It 'returns the input when target is not under base' {
        $from = 'C:\root\bucket'
        $to = 'C:\other\foo.json'
        Get-RelativePath $from $to | Should-Be $to
    }
}

Describe 'is_in_dir' -Tag 'Scoop' {
    It 'returns false when path is not under dir' {
        is_in_dir 'C:\test' 'C:\foo' | Should-BeFalse
    }
    It 'returns true when path is under dir' {
        is_in_dir 'C:\test' 'C:\test\foo\baz.zip' | Should-BeTrue
    }
    It 'returns true when dir has a trailing separator' {
        is_in_dir "$PSScriptRoot\..\" "$PSScriptRoot" | Should-BeTrue
    }
    It 'returns false when path escapes dir through dot segments' {
        is_in_dir 'C:\test\sub' 'C:\test\sub\..\..\Windows\notepad.exe' | Should-BeFalse
    }
}

Describe 'currentdir' -Tag 'Scoop' {
    It 'resolves version directory when NO_JUNCTION is enabled without preloading versions.ps1' {
        Mock get_config { $true } -ParameterFilter { $name -eq 'NO_JUNCTION' }
        Mock appdir { 'C:\scoop\apps\git' }
        $null = & { currentdir 'git' $false }
    }
    It 'returns the junction path when NO_JUNCTION is disabled' {
        Mock get_config { $false } -ParameterFilter { $name -eq 'NO_JUNCTION' }
        Mock appdir { 'C:\scoop\apps\git' }
        currentdir 'git' $false | Should-Be 'C:\scoop\apps\git\current'
    }
    It 'keeps using the junction for scoop itself' {
        Mock get_config { $true } -ParameterFilter { $name -eq 'NO_JUNCTION' }
        Mock appdir { 'C:\scoop\apps\scoop' }
        currentdir 'scoop' $false | Should-Be 'C:\scoop\apps\scoop\current'
    }
}

Describe 'sanitary_path' -Tag 'Scoop' {
    It 'removes invalid path characters from a string' {
        $path = 'test?.json'
        $valid_path = sanitary_path $path

        $valid_path | Should-Be 'test.json'
    }
}

Describe 'app' -Tag 'Scoop' {
    It 'parses the bucket name from an app query' {
        $query = 'C:\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'C:\test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = 'test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = '.\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be '.\test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = '..\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be '..\test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = '\\share\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be '\\share\test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = 'https://example.com/test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'https://example.com/test.json'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = 'test'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = 'extras/enso'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'enso'
        $bucket | Should-Be 'extras'
        $version | Should-BeNull

        $query = 'test-app'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test-app'
        $bucket | Should-BeNull
        $version | Should-BeNull

        $query = 'test-bucket/test-app'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test-app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-BeNull

        $query = 'test-bucket/test-app@1.8.0'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test-app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-Be '1.8.0'

        $query = 'test-bucket/test-app@1.8.0-rc2'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test-app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-Be '1.8.0-rc2'

        $query = 'test-bucket/test_app'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test_app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-BeNull

        $query = 'test-bucket/test_app@1.8.0'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test_app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-Be '1.8.0'

        $query = 'test-bucket/test_app@1.8.0-rc2'
        $app, $bucket, $version = parse_app $query
        $app | Should-Be 'test_app'
        $bucket | Should-Be 'test-bucket'
        $version | Should-Be '1.8.0-rc2'
    }
}

Describe 'Get-PEMachine' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        # pin the switch input and the install root, so the machine's config cannot decide the verdict
        $repo_root = Join-Path $PSScriptRoot '..'
        Mock -CommandName get_config -MockWith { 'scoopcs' } -ParameterFilter { $Name -eq 'SHIM' }
        Mock -CommandName versiondir -MockWith { $repo_root } -ParameterFilter { $app -eq 'scoop' -and $version -eq 'current' }
    }

    It 'returns machine type for a valid PE file' {
        $shim_path = get_shim_path
        $shim_path | Should-BeLikeString '*\supporting\shims\scoopcs\shim.exe'
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
        # CI checkouts have no installed scoop version dir, so point at the bundled shim.exe
        $repo_shim = Join-Path $PSScriptRoot '..\supporting\shims\scoopcs\shim.exe'
        Mock -CommandName get_shim_path -MockWith { $repo_shim }
    }

    It 'rewrites System32 to Sysnative in the shim file when the shim exe is x86 on x64 OS' {
        $target = "$env:SystemRoot\System32\notepad.exe"
        $rewrites = [System.Environment]::Is64BitOperatingSystem -and (Get-PEMachine (get_shim_path)) -eq 0x014c

        shim $target $false 'wow64-test'

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

        shim $target $false 'wow64-test'

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
        $rewrites = [System.Environment]::Is64BitOperatingSystem -and (Get-PEMachine (get_shim_path)) -eq 0x014c

        shim $target $false 'wow64-test'

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
        rm_shim 'wow64-test' $shimdir
    }
}

Describe 'Format Architecture String' -Tag 'Scoop' {
    It 'should keep correct architectures' {
        Format-ArchitectureString '32bit' | Should-Be '32bit'
        Format-ArchitectureString '32' | Should-Be '32bit'
        Format-ArchitectureString 'x86' | Should-Be '32bit'
        Format-ArchitectureString 'X86' | Should-Be '32bit'
        Format-ArchitectureString 'i386' | Should-Be '32bit'
        Format-ArchitectureString '386' | Should-Be '32bit'
        Format-ArchitectureString 'i686' | Should-Be '32bit'

        Format-ArchitectureString '64bit' | Should-Be '64bit'
        Format-ArchitectureString '64' | Should-Be '64bit'
        Format-ArchitectureString 'x64' | Should-Be '64bit'
        Format-ArchitectureString 'X64' | Should-Be '64bit'
        Format-ArchitectureString 'amd64' | Should-Be '64bit'
        Format-ArchitectureString 'AMD64' | Should-Be '64bit'
        Format-ArchitectureString 'x86_64' | Should-Be '64bit'
        Format-ArchitectureString 'x86-64' | Should-Be '64bit'

        Format-ArchitectureString 'arm64' | Should-Be 'arm64'
        Format-ArchitectureString 'arm' | Should-Be 'arm64'
        Format-ArchitectureString 'aarch64' | Should-Be 'arm64'
        Format-ArchitectureString 'ARM64' | Should-Be 'arm64'
        Format-ArchitectureString 'ARM' | Should-Be 'arm64'
        Format-ArchitectureString 'AARCH64' | Should-Be 'arm64'
    }

    It 'should fallback to the default architecture on empty input' {
        Format-ArchitectureString '' | Should-Be $(Get-DefaultArchitecture)
        Format-ArchitectureString $null | Should-Be $(Get-DefaultArchitecture)
    }

    It 'should show an error with an invalid architecture' {
        { Format-ArchitectureString 'PPC' } | Should-Throw "*Invalid architecture: 'ppc'*"
    }
}

Describe 'substitute' -Tag 'Scoop' {
    It 'should properly handle keys that are substrings of other keys' {
        $params = @{}

        # Run repeatedly (10 times) to reduce the likelihood of accidental correct ordering.
        1 .. 10 | ForEach-Object {
            $params["`$name$($_)"] = "$($_).exe"
            $params["`$name$($_)NoExt"] = "$_"

            substitute ("`$name$($_)NoExt") $params $false | Should-Be "$_"
        }
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
}

Describe 'Get-CommandLiteral' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $pathDir = Join-Path $TestDrive 'literal-path'
        $lookalikeDir = Join-Path $TestDrive 'literal-lookalike'
        $decoyDir = Join-Path $TestDrive 'literal-decoy'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        $null = [IO.Directory]::CreateDirectory($lookalikeDir)
        $null = [IO.Directory]::CreateDirectory($decoyDir)
        [IO.File]::WriteAllText("$pathDir\br[a]cket.exe", '')
        [IO.File]::WriteAllText("$lookalikeDir\bracket.exe", '')
        [IO.File]::WriteAllText("$decoyDir\clasper.exe", '')
    }

    It 'resolves a command name containing a wildcard character to the literal file on PATH' {
        $oldPath = $env:PATH
        $rest = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $pathDir -and $_ -ne $lookalikeDir -and $_ -ne $decoyDir }) -join ';'
        $env:PATH = "$pathDir;$lookalikeDir;$rest"
        try {
            (Get-CommandLiteral 'br[a]cket.exe').Path | Should-Be "$pathDir\br[a]cket.exe"
        } finally {
            $env:PATH = $oldPath
        }
    }

    It 'returns nothing for a command that does not exist' {
        Get-CommandLiteral 'scoop-no-such-command' | Should-BeNull
    }

    It 'does not resolve a wildcard command name from a look-alike on PATH' {
        $oldPath = $env:PATH
        $rest = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $pathDir -and $_ -ne $lookalikeDir -and $_ -ne $decoyDir }) -join ';'
        $env:PATH = "$decoyDir;$rest"
        try {
            Get-CommandLiteral 'cl[a]sper.exe' | Should-BeNull
        } finally {
            $env:PATH = $oldPath
        }
    }
}

Describe 'Get-CommandPath' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        $pathDir = Join-Path $TestDrive 'literal-path'
        $lookalikeDir = Join-Path $TestDrive 'literal-lookalike'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        $null = [IO.Directory]::CreateDirectory($lookalikeDir)
        [IO.File]::WriteAllText("$pathDir\br[a]cket.exe", '')
        [IO.File]::WriteAllText("$lookalikeDir\bracket.exe", '')
    }

    It 'resolves a command name containing a wildcard character to the literal file' {
        $pathDir = Join-Path $TestDrive 'literal-path'
        $lookalikeDir = Join-Path $TestDrive 'literal-lookalike'
        $oldPath = $env:PATH
        $rest = (($oldPath -split ';') | Where-Object { $_ -and $_ -ne $pathDir -and $_ -ne $lookalikeDir }) -join ';'
        $env:PATH = "$pathDir;$lookalikeDir;$rest"
        try {
            Get-CommandPath 'br[a]cket.exe' | Should-Be "$pathDir\br[a]cket.exe"
        } finally {
            $env:PATH = $oldPath
        }
    }
}
