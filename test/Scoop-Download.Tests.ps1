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

Describe 'Get-GitHubApiAccept' -Tag 'Scoop' {
    It 'omits octet-stream for Actions artifact zips so they redirect instead of 415' {
        Get-GitHubApiAccept 'https://api.github.com/repos/vpinball/vpinball/actions/artifacts/11138249207/zip' | Should -BeNullOrEmpty
    }

    It 'omits octet-stream for an artifact zip after the filename-override fragment is stripped' {
        # Invoke-Download passes the fragment-free url; a manifest may append #/app.zip for extraction
        $url = 'https://api.github.com/repos/vpinball/vpinball/actions/artifacts/11138249207/zip#/VPinballX_BGFX.zip'
        Get-GitHubApiAccept (($url -split '#')[0]) | Should -BeNullOrEmpty
    }

    It 'keeps octet-stream for release assets so they return the binary' {
        Get-GitHubApiAccept 'https://api.github.com/repos/cli/cli/releases/assets/599854636' | Should -Be 'application/octet-stream'
    }

    It 'keeps octet-stream for other api.github.com paths' {
        Get-GitHubApiAccept 'https://api.github.com/repos/vpinball/vpinball/actions/artifacts/11138249207' | Should -Be 'application/octet-stream'
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
