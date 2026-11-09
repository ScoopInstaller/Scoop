BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
}

Describe 'Test-Aria2Enabled' -Tag 'Scoop' {
    It 'should return true if aria2 is installed' {
        Mock Test-HelperInstalled { $true }
        Mock get_config { $true }
        Test-Aria2Enabled | Should-BeTrue
    }

    It 'should return false if aria2 is not installed' {
        Mock Test-HelperInstalled { $false }
        Mock get_config { $false }
        Test-Aria2Enabled | Should-BeFalse

        Mock Test-HelperInstalled { $false }
        Mock get_config { $true }
        Test-Aria2Enabled | Should-BeFalse

        Mock Test-HelperInstalled { $true }
        Mock get_config { $false }
        Test-Aria2Enabled | Should-BeFalse
    }
}

Describe 'New-DownloadRequest Accept header' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-UserAgent { 'Scoop-Test' }
        Mock Get-GitHubToken { 'fake-token' }
        Mock get_config { }
    }

    It 'omits the Accept header for an Actions artifact zip so it is not rejected with 415' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207/zip'
        $req.Accept | Should-BeNull
    }

    It 'omits the Accept header for an artifact zip even when a filename-override fragment is appended' {
        # Exercises the $reqUrl fragment-strip + Accept-check interaction (the original bug)
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207/zip#/example.zip'
        $req.Accept | Should-BeNull
    }

    It 'sets octet-stream Accept for a release asset so it returns the binary' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/releases/assets/599854636'
        $req.Accept | Should-Be 'application/octet-stream'
    }

    It 'sets octet-stream Accept for other api.github.com paths' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207'
        $req.Accept | Should-Be 'application/octet-stream'
    }
}

Describe 'New-DownloadRequest Authorization header' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-UserAgent { 'Scoop-Test' }
        Mock get_config { }
        $apiUrl = 'https://api.github.com/repos/example/example/releases/assets/599854636'
    }

    It 'sets the header only when a token exists' {
        Mock Get-GitHubToken { 'fake-token' }
        (New-DownloadRequest $apiUrl).Headers['Authorization'] | Should-Be 'Bearer fake-token'

        Mock Get-GitHubToken { }
        (New-DownloadRequest $apiUrl).Headers['Authorization'] | Should-BeNull

        Mock Get-GitHubToken { '' }
        (New-DownloadRequest $apiUrl).Headers['Authorization'] | Should-BeNull
    }
}

Describe 'download_json' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-GitHubToken { 'fake-token' }
    }

    It 'follows a redirect to <final> with the token' -TestCases @(
        @{ start = 'https://api.github.com/repos/example/example'; redirect = 'https://api.github.com/repositories/1'; final = 'https://api.github.com/repositories/1' }
        @{ start = 'https://example.com/checksums'; redirect = '/checksums/latest.json'; final = 'https://example.com/checksums/latest.json' }
    ) {
        Mock Get-GitHubApiResponse {
            if ($uri -eq $start) {
                [PSCustomObject]@{ StatusCode = 302; Location = $redirect; Content = '' }
            } else {
                [PSCustomObject]@{ StatusCode = 200; Location = ''; Content = '{"private":true}' }
            }
        }
        (download_json $start).private | Should-BeTrue
        Should-Invoke -CommandName Get-GitHubApiResponse -ParameterFilter { $uri -eq $final -and $token -eq 'fake-token' } -Times 1 -Exactly
    }

    It 'does not send the token to <redirect>' -TestCases @(
        @{ redirect = 'https://example.com/repositories/1' }
        @{ redirect = 'http://api.github.com/repositories/1' }
    ) {
        Mock Get-GitHubApiResponse {
            [PSCustomObject]@{ StatusCode = 302; Location = $redirect; Content = '' }
        }
        { download_json 'https://api.github.com/repos/example/example' } | Should-Throw
        Should-Invoke -CommandName Get-GitHubApiResponse -Times 1 -Exactly
    }
}

Describe 'Get-Encoding' -Tag 'Scoop' {
    It 'reads the charset of a <source>' -TestCases @(
        @{ source = 'http response'; response = @{ Headers = @{ 'Content-Type' = 'application/json; charset=iso-8859-1' } }; charset = 'iso-8859-1' }
        @{ source = 'web client'; response = @{ ResponseHeaders = @{ 'Content-Type' = 'text/plain; charset=utf-16' } }; charset = 'utf-16' }
    ) {
        (Get-Encoding ([PSCustomObject]$response)).WebName | Should-Be $charset
    }
}

Describe 'handle_special_urls' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-GitHubToken { 'fake-token' }
        $url = 'https://github.com/example/example/releases/download/v1.0/app.zip'
    }

    It 'keeps the original url when the token cannot be used' {
        Mock Get-GitHubApiResponse { throw 'Bad credentials' }
        handle_special_urls $url | Should-Be $url
    }
}

Describe 'url_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can be tricked with a hash to override the real filename' {
        url_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo.zip'
    }
}

Describe 'url_remote_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_remote_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_remote_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can not be tricked with a hash to override the real filename' {
        url_remote_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo-v2.zip'
    }
}

Describe 'Get-GitHubToken' -Tag 'Scoop' {
    BeforeAll {
        # Mock needs a real command to replace; a 'function' statement would trip the linter.
        Set-Item -Path function:script:gh -Value { 'gho_realCliMustNotRun' }

        $tokenVars = 'SCOOP_GH_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN'
        $origEnv = @{}
        $tokenVars | ForEach-Object { $origEnv[$_] = [Environment]::GetEnvironmentVariable($_) }
    }

    AfterAll {
        Remove-Item -Path function:script:gh -ErrorAction Ignore
        $origEnv.Keys | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $origEnv[$_]) }
    }

    BeforeEach {
        Mock get_config { $null }
        Mock gh { 'gho_FROM_CLI' }
        $tokenVars | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $null) }
        # Remove rather than assign, so each test also covers the unassigned first call
        Remove-Variable -Name ghCliToken -Scope Script -ErrorAction Ignore
    }

    It 'should give up when the GitHub CLI fails, and not retry it' {
        Mock gh { throw 'gh: could not read token' }
        Get-GitHubToken | Should-BeNull
        Get-GitHubToken | Should-BeNull
        Should-Invoke -CommandName gh -Times 1 -Exactly
    }

    # checkver.ps1 and autoupdate.ps1 call this without bin/scoop.ps1's 'Set-StrictMode -Off'
    It 'tolerates StrictMode when no token source is set' {
        Mock gh { }
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-BeNull
    }

    It 'tolerates StrictMode when reading the probe cache before it was assigned' {
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-Be 'gho_FROM_CLI'
    }
}
