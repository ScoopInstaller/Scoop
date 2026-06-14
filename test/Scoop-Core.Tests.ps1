BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
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
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should -Be 'local\i_am_a_file.txt'
    }

    It 'should return globally installed program' {
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq 'local\i_am_a_file.txt' }
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq 'global\i_am_a_file.txt' }
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should -Be 'global\i_am_a_file.txt'
    }

    It 'should return null if program is not installed' {
        Get-AppFilePath -App 'is_directory' -File 'i_do_not_exist' | Should -BeNullOrEmpty
    }

    It 'should throw if parameter is wrong or missing' {
        { Get-AppFilePath -App 'is_directory' -File } | Should -Throw
        { Get-AppFilePath -App -File 'i_am_a_file.txt' } | Should -Throw
        { Get-AppFilePath -App -File } | Should -Throw
    }
}

Describe 'Get-HelperPath' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'is_directory'
    }
    It 'should return path if program is installed' {
        Mock Get-AppFilePath { '7zip\current\7z.exe' }
        Get-HelperPath -Helper 7zip | Should -Be '7zip\current\7z.exe'
    }

    It 'should return null if program is not installed' {
        Mock Get-AppFilePath { $null }
        Get-HelperPath -Helper 7zip | Should -BeNullOrEmpty
    }

    It 'should throw if parameter is wrong or missing' {
        { Get-HelperPath -Helper } | Should -Throw
        { Get-HelperPath -Helper Wrong } | Should -Throw
    }
}


Describe 'Test-HelperInstalled' -Tag 'Scoop' {
    It 'should return true if program is installed' {
        Mock Get-HelperPath { '7z.exe' }
        Test-HelperInstalled -Helper 7zip | Should -BeTrue
    }

    It 'should return false if program is not installed' {
        Mock Get-HelperPath { $null }
        Test-HelperInstalled -Helper 7zip | Should -BeFalse
    }

    It 'should throw if parameter is wrong or missing' {
        { Test-HelperInstalled -Helper } | Should -Throw
        { Test-HelperInstalled -Helper Wrong } | Should -Throw
    }
}

Describe 'Test-CommandAvailable' -Tag 'Scoop' {
    It 'should return true if command exists' {
        Test-CommandAvailable 'Write-Host' | Should -BeTrue
    }

    It "should return false if command doesn't exist" {
        Test-CommandAvailable 'Write-ThisWillProbablyNotExist' | Should -BeFalse
    }

    It 'should throw if parameter is wrong or missing' {
        { Test-CommandAvailable } | Should -Throw
    }
}


Describe 'is_directory' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'is_directory'
    }

    It 'is_directory recognize directories' {
        is_directory "$working_dir\i_am_a_directory" | Should -Be $true
    }
    It 'is_directory recognize files' {
        is_directory "$working_dir\i_am_a_file.txt" | Should -Be $false
    }

    It 'is_directory is falsey on unknown path' {
        is_directory "$working_dir\i_do_not_exist" | Should -Be $false
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

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist
    }

    It 'moves directories with spaces in path' {
        $dir = "$working_dir\user with space"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist

        # test trailing \ in from dir
        movedir "$dir\_tmp\$null" "$dir\another"
        "$dir\another\test.txt" | Should -FileContentMatch 'testing'
        "$dir\_tmp" | Should -Not -Exist
    }

    It 'moves directories with quotes in path' {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist
    }
}

Describe 'cache_path' -Tag 'Scoop' {
    It 'returns the correct cache path for a given input' {
        $url = 'https://example.com/git.zip'
        $ret = cache_path 'git' '2.44.0' $url
        $inputStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($url))
        $sha = (Get-FileHash -Algorithm SHA256 -InputStream $inputStream).Hash.ToLower().Substring(0, 7)
        $ret | Should -Be "$cachedir\git#2.44.0#$sha.zip"
    }

    # # NOTE: Remove this 6 months after the feature ships.
    It 'returns the old format cache path for a given input' {
        Mock Test-Path { $true }
        $ret = cache_path 'git' '2.44.0' 'https://example.com/git.zip'
        $ret | Should -Be "$cachedir\git#2.44.0#https_example.com_git.zip"
    }
}

Describe 'Get-RelativePath' -Tag 'Scoop' {
    It 'returns relative path for child path' {
        $from = 'C:\root\bucket'
        $to = 'C:\root\bucket\foo\bar.json'
        Get-RelativePath $from $to | Should -Be 'foo\bar.json'
    }
    It 'returns original when different drive/scheme' {
        $from = 'C:\root\bucket'
        $to = 'D:\other\file.json'
        Get-RelativePath $from $to | Should -Be $to
    }
    It 'handles paths containing characters that break [System.Uri]' {
        $from = 'C:\b#ucket'
        $to = 'C:\b#ucket\foo.json'
        Get-RelativePath $from $to | Should -Be 'foo.json'
    }
    It 'returns the input when target is not under base' {
        $from = 'C:\root\bucket'
        $to = 'C:\other\foo.json'
        Get-RelativePath $from $to | Should -Be $to
    }
}

Describe 'is_in_dir' -Tag 'Scoop' {
    It 'returns false when path is not under dir' {
        is_in_dir 'C:\test' 'C:\foo' | Should -BeFalse
    }
    It 'returns true when path is under dir' {
        is_in_dir 'C:\test' 'C:\test\foo\baz.zip' | Should -BeTrue
    }
    It 'returns false when path is the parent dir itself' {
        is_in_dir "$PSScriptRoot\..\" "$PSScriptRoot" | Should -BeFalse
    }
}

Describe 'sanitary_path' -Tag 'Scoop' {
    It 'removes invalid path characters from a string' {
        $path = 'test?.json'
        $valid_path = sanitary_path $path

        $valid_path | Should -Be 'test.json'
    }
}

Describe 'app' -Tag 'Scoop' {
    It 'parses the bucket name from an app query' {
        $query = 'C:\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'C:\test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = 'test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = '.\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be '.\test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = '..\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be '..\test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = '\\share\test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be '\\share\test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = 'https://example.com/test.json'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'https://example.com/test.json'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = 'test'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = 'extras/enso'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'enso'
        $bucket | Should -Be 'extras'
        $version | Should -BeNullOrEmpty

        $query = 'test-app'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test-app'
        $bucket | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty

        $query = 'test-bucket/test-app'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test-app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -BeNullOrEmpty

        $query = 'test-bucket/test-app@1.8.0'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test-app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -Be '1.8.0'

        $query = 'test-bucket/test-app@1.8.0-rc2'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test-app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -Be '1.8.0-rc2'

        $query = 'test-bucket/test_app'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test_app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -BeNullOrEmpty

        $query = 'test-bucket/test_app@1.8.0'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test_app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -Be '1.8.0'

        $query = 'test-bucket/test_app@1.8.0-rc2'
        $app, $bucket, $version = parse_app $query
        $app | Should -Be 'test_app'
        $bucket | Should -Be 'test-bucket'
        $version | Should -Be '1.8.0-rc2'
    }
}

Describe 'Format Architecture String' -Tag 'Scoop' {
    It 'should keep correct architectures' {
        Format-ArchitectureString '32bit' | Should -Be '32bit'
        Format-ArchitectureString '32' | Should -Be '32bit'
        Format-ArchitectureString 'x86' | Should -Be '32bit'
        Format-ArchitectureString 'X86' | Should -Be '32bit'
        Format-ArchitectureString 'i386' | Should -Be '32bit'
        Format-ArchitectureString '386' | Should -Be '32bit'
        Format-ArchitectureString 'i686' | Should -Be '32bit'

        Format-ArchitectureString '64bit' | Should -Be '64bit'
        Format-ArchitectureString '64' | Should -Be '64bit'
        Format-ArchitectureString 'x64' | Should -Be '64bit'
        Format-ArchitectureString 'X64' | Should -Be '64bit'
        Format-ArchitectureString 'amd64' | Should -Be '64bit'
        Format-ArchitectureString 'AMD64' | Should -Be '64bit'
        Format-ArchitectureString 'x86_64' | Should -Be '64bit'
        Format-ArchitectureString 'x86-64' | Should -Be '64bit'

        Format-ArchitectureString 'arm64' | Should -Be 'arm64'
        Format-ArchitectureString 'arm' | Should -Be 'arm64'
        Format-ArchitectureString 'aarch64' | Should -Be 'arm64'
        Format-ArchitectureString 'ARM64' | Should -Be 'arm64'
        Format-ArchitectureString 'ARM' | Should -Be 'arm64'
        Format-ArchitectureString 'AARCH64' | Should -Be 'arm64'
    }

    It 'should fallback to the default architecture on empty input' {
        Format-ArchitectureString '' | Should -Be $(Get-DefaultArchitecture)
        Format-ArchitectureString $null | Should -Be $(Get-DefaultArchitecture)
    }

    It 'should show an error with an invalid architecture' {
        { Format-ArchitectureString 'PPC' } | Should -Throw "Invalid architecture: 'ppc'"
    }
}

Describe 'substitute' -Tag 'Scoop' {
    It 'should properly handle keys that are substrings of other keys' {
        $params = @{}

        # Run repeatedly (10 times) to reduce the likelihood of accidental correct ordering.
        1 .. 10 | ForEach-Object {
            $params["`$name$($_)"] = "$($_).exe"
            $params["`$name$($_)NoExt"] = "$_"

            substitute ("`$name$($_)NoExt") $params $false | Should -Be "$_"
        }
    }
}
