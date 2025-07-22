BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
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

Describe 'url_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_filename 'http://example.org/foo.txt' | Should -Be 'foo.txt'
        url_filename 'http://example.org/foo.txt?var=123' | Should -Be 'foo.txt'
    }

    It 'can be tricked with a hash to override the real filename' {
        url_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should -Be 'foo.zip'
    }
}

Describe 'url_remote_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_remote_filename 'http://example.org/foo.txt' | Should -Be 'foo.txt'
        url_remote_filename 'http://example.org/foo.txt?var=123' | Should -Be 'foo.txt'
    }

    It 'can not be tricked with a hash to override the real filename' {
        url_remote_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should -Be 'foo-v2.zip'
    }
}

Describe 'check_hash' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'decompress'
        $testcases = "$working_dir\TestCases.zip"
        Mock url_remote_filename { 'TestCases.zip' }
        Mock Write-Host { }
    }

    It 'should return true for a valid sha256 hash' {
        Mock get_config { $false } -ParameterFilter { $name -eq 'allow_no_hash' }
        $ok, $err = check_hash $testcases '591072faabd419b77932b7023e5899b4e05c0bf8e6859ad367398e6bfe1eb203' 'TestCases'
        $ok | Should -BeTrue
        $err | Should -BeNullOrEmpty
    }

    It 'should return true for a valid non-sha256 hash' {
        Mock get_config { $false } -ParameterFilter { $name -eq 'allow_no_hash' }
        $ok, $err = check_hash $testcases 'sha512:ed47a7fa15c85be8348ecc0e8a8d6140e3caa72ad344c7a3313a026fed0ac07432b969751cb09484045b4335a53c5031ea7e3c0c2802f8f02a4ebe3d27129dc2' 'TestCases'
        $ok | Should -BeTrue
        $err | Should -BeNullOrEmpty
    }

    It 'should return false for an invalid hash' {
        Mock get_config { $false } -ParameterFilter { $name -eq 'allow_no_hash' }
        $ok, $err = check_hash $testcases '591072faabd419b79932b7023e5899b4e05c0bf8e6859ad367398e6bfe1eb203' 'TestCases'
        $ok | Should -BeFalse
        $err | Should -Match 'Hash check failed'
    }

    It 'should return false for a null hash' {
        Mock get_config { $false } -ParameterFilter { $name -eq 'allow_no_hash' }
        $ok, $err = check_hash $testcases $null 'TestCases'
        $ok | Should -BeFalse
        $err | Should -Match 'No hash provided in manifest'
    }

    It 'should return true for a null hash with allow_no_hash set to true' {
        Mock get_config { $true } -ParameterFilter { $name -eq 'allow_no_hash' }
        $ok, $err = check_hash $testcases $null 'TestCases'
        $ok | Should -BeTrue
        $err | Should -BeNullOrEmpty
    }

    AfterAll {
        Remove-Item -Path $working_dir -Recurse -Force
    }
}
