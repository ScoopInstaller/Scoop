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

    It 'sends the token to the GitHub API' {
        Mock Get-GitHubToken { 'fake-token' }
        $req = New-DownloadRequest $apiUrl
        $req.Headers['Authorization'] | Should-Be 'Bearer fake-token'
    }

    It 'omits the header if there is no token' {
        Mock Get-GitHubToken { }
        $req = New-DownloadRequest $apiUrl
        $req.Headers['Authorization'] | Should-BeNull
    }

    It 'omits the header if the token is an empty string' {
        Mock Get-GitHubToken { '' }
        $req = New-DownloadRequest $apiUrl
        $req.Headers['Authorization'] | Should-BeNull
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
        $tokenVars = 'SCOOP_GH_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN'
        $origEnv = @{}
        $tokenVars | ForEach-Object { $origEnv[$_] = [Environment]::GetEnvironmentVariable($_) }
    }

    AfterAll {
        $origEnv.Keys | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $origEnv[$_]) }
    }

    BeforeEach {
        Mock get_config { $null }
        Mock Test-CommandAvailable { $true }
        Mock gh { 'gho_FROM_CLI' }
        $tokenVars | ForEach-Object { [Environment]::SetEnvironmentVariable($_, $null) }
        # Clear the per-process probe cache by removing it rather than assigning, so every
        # test also exercises the uninitialized first-call path that StrictMode rejects
        Remove-Variable -Name ghCliToken -Scope Script -ErrorAction Ignore
    }

    It 'should prefer $env:SCOOP_GH_TOKEN over every other source' {
        Mock get_config { 'from_config' }
        $env:SCOOP_GH_TOKEN = 'from_scoop_env'
        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should-Be 'from_scoop_env'
        Should-Invoke -CommandName gh -Times 0 -Exactly
    }

    It 'should prefer the config over the environment and the GitHub CLI' {
        Mock get_config { 'from_config' }
        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should-Be 'from_config'
        Should-Invoke -CommandName gh -Times 0 -Exactly
    }

    It 'should not use the environment or the GitHub CLI if the config is an empty string' {
        Mock get_config { '' }
        $env:GH_TOKEN = 'from_gh_env'
        $env:GITHUB_TOKEN = 'from_github_env'
        Get-GitHubToken | Should-BeEmptyString
        Should-Invoke -CommandName gh -Times 0 -Exactly
    }

    It 'should still prefer $env:SCOOP_GH_TOKEN if the config is an empty string' {
        Mock get_config { '' }
        $env:SCOOP_GH_TOKEN = 'from_scoop_env'
        Get-GitHubToken | Should-Be 'from_scoop_env'
    }

    It 'should ignore a config that is not a string' {
        Mock get_config { $false }
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'

        Mock get_config { $true }
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
    }

    It 'should query the GitHub CLI by default' {
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
        Should-Invoke -CommandName gh -Times 1 -Exactly
    }

    It 'should ask the GitHub CLI for the github.com token' {
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
        Should-Invoke -CommandName gh -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'auth token --hostname github.com'
        }
    }

    It 'should prefer the GitHub CLI over $env:GH_TOKEN and $env:GITHUB_TOKEN' {
        $env:GH_TOKEN = 'from_gh_env'
        $env:GITHUB_TOKEN = 'from_github_env'
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
    }

    It 'should query the GitHub CLI at most once per process' {
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
        Get-GitHubToken | Should-Be 'gho_FROM_CLI'
        Should-Invoke -CommandName gh -Times 1 -Exactly
    }

    It 'should not query the GitHub CLI if it is not installed' {
        Mock Test-CommandAvailable { $false }
        Get-GitHubToken | Should-BeNull
        Should-Invoke -CommandName gh -Times 0 -Exactly
    }

    It 'should return nothing if the GitHub CLI is not logged in' {
        Mock gh { }
        Get-GitHubToken | Should-BeNull
    }

    It 'should return nothing if the GitHub CLI fails' {
        Mock gh { throw 'gh: could not read token' }
        Get-GitHubToken | Should-BeNull
    }

    It 'should not retry the GitHub CLI after a failed probe' {
        Mock gh { }
        Get-GitHubToken | Should-BeNull
        Get-GitHubToken | Should-BeNull
        Should-Invoke -CommandName gh -Times 1 -Exactly
    }

    It 'should fall back to $env:GH_TOKEN, then $env:GITHUB_TOKEN, if the GitHub CLI is not installed' {
        Mock Test-CommandAvailable { $false }
        $env:GITHUB_TOKEN = 'from_github_env'
        Get-GitHubToken | Should-Be 'from_github_env'

        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should-Be 'from_gh_env'
    }

    It 'should fall back to the environment if the GitHub CLI is not logged in' {
        Mock gh { }
        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should-Be 'from_gh_env'
    }

    It 'should fall back to the environment if the GitHub CLI fails' {
        Mock gh { throw 'gh: could not read token' }
        $env:GITHUB_TOKEN = 'from_github_env'
        Get-GitHubToken | Should-Be 'from_github_env'
    }

    # Callers reached from a user's own session are not shielded by the 'Set-StrictMode -Off'
    # in bin/scoop.ps1 -- bin/checkver.ps1 and lib/autoupdate.ps1 both call this directly
    It 'tolerates StrictMode when no token source is set' {
        # Unset sources are $null, and StrictMode turns the property access that filters
        # them into an error, which only becomes terminating under $ErrorActionPreference
        Mock Test-CommandAvailable { $false }
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-BeNull
    }

    It 'tolerates StrictMode when querying the GitHub CLI' {
        # The probe cache is read before it is ever assigned
        & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } | Should-Be 'gho_FROM_CLI'
    }
}
