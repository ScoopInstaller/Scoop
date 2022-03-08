. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\unix.ps1"
. "$PSScriptRoot\Scoop-TestLib.ps1"

$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName
$isUnix = is_unix

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

Describe 'Test-Aria2Enabled' -Tag 'Scoop' {
    It 'should return true if aria2 is installed' {
        Mock Test-HelperInstalled { $true }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeTrue
    }

    It 'should return false if aria2 is not installed' {
        Mock Test-HelperInstalled { $false }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $false }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $true }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse
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

Describe 'movedir' -Tag 'Scoop' {
    $extract_dir = 'subdir'
    $extract_to = $null

    BeforeAll {
        $working_dir = setup_working 'movedir'
    }

    It 'moves directories with no spaces in path' -Skip:$isUnix {
        $dir = "$working_dir\user"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist
    }

    It 'moves directories with spaces in path' -Skip:$isUnix {
        $dir = "$working_dir\user with space"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist

        # test trailing \ in from dir
        movedir "$dir\_tmp\$null" "$dir\another"
        "$dir\another\test.txt" | Should -FileContentMatch 'testing'
        "$dir\_tmp" | Should -Not -Exist
    }

    It 'moves directories with quotes in path' -Skip:$isUnix {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | Should -FileContentMatch 'this is the one'
        "$dir\_tmp\$extract_dir" | Should -Not -Exist
    }
}

Describe 'shim' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | Out-Null
    }

    It "links a file onto the user's path" -Skip:$isUnix {
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

    Context 'user with quote' {
        It 'shims a file with quote in path' -Skip:$isUnix {
            { Get-Command 'shim-test' -ea stop } | Should -Throw
            { shim-test } | Should -Throw

            shim "$working_dir\user with 'quote\shim-test.ps1" $false 'shim-test'
            { Get-Command 'shim-test' -ea stop } | Should -Not -Throw
            shim-test | Should -Be 'Hello, world!'
        }
    }

    AfterEach {
        rm_shim 'shim-test' $shimdir
    }
}

Describe 'rm_shim' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | Out-Null
    }

    It 'removes shim from path' -Skip:$isUnix {
        shim "$working_dir\shim-test.ps1" $false 'shim-test'

        rm_shim 'shim-test' $shimdir

        { Get-Command 'shim-test' -ea stop } | Should -Throw
        { Get-Command 'shim-test.ps1' -ea stop } | Should -Throw
        { Get-Command 'shim-test.cmd' -ea stop } | Should -Throw
        { shim-test } | Should -Throw
    }
}

Describe 'get_app_name_from_shim' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'shim'
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | Out-Null
        Mock appsdir { $working_dir }
    }

    It 'returns empty string if file does not exist' -Skip:$isUnix {
        get_app_name_from_shim 'non-existent-file' | Should -Be ''
    }

    It 'returns app name if file exists and is a shim to an app' -Skip:$isUnix {
        mkdir -p "$working_dir/mockapp/current/"
        Write-Output '' | Out-File "$working_dir/mockapp/current/mockapp1.ps1"
        shim "$working_dir/mockapp/current/mockapp1.ps1" $false 'shim-test1'
        $shim_path1 = (Get-Command 'shim-test1.ps1').Path
        get_app_name_from_shim "$shim_path1" | Should -Be 'mockapp'
        mkdir -p "$working_dir/mockapp/1.0.0/"
        Write-Output '' | Out-File "$working_dir/mockapp/1.0.0/mockapp2.ps1"
        shim "$working_dir/mockapp/1.0.0/mockapp2.ps1" $false 'shim-test2'
        $shim_path2 = (Get-Command 'shim-test2.ps1').Path
        get_app_name_from_shim "$shim_path2" | Should -Be 'mockapp'
    }

    It 'returns empty string if file exists and is not a shim' -Skip:$isUnix {
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

Describe 'ensure_robocopy_in_path' -Tag 'Scoop' {
    $shimdir = shimdir $false
    Mock versiondir { $repo_dir }

    BeforeAll {
        reset_aliases
    }

    Context 'robocopy is not in path' {
        It 'shims robocopy when not on path' -Skip:$isUnix {
            Mock Test-CommandAvailable { $false }
            Test-CommandAvailable robocopy | Should -Be $false

            ensure_robocopy_in_path

            # "$shimdir/robocopy.ps1" | should -exist
            "$shimdir/robocopy.exe" | Should -Exist

            # clean up
            rm_shim robocopy $(shimdir $false) | Out-Null
        }
    }

    Context 'robocopy is in path' {
        It 'does not shim robocopy when it is in path' -Skip:$isUnix {
            Mock Test-CommandAvailable { $true }
            Test-CommandAvailable robocopy | Should -Be $true

            ensure_robocopy_in_path

            # "$shimdir/robocopy.ps1" | should -not -exist
            "$shimdir/robocopy.exe" | Should -Not -Exist
        }
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
