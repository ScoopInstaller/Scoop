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

Describe 'Get-GitHubToken' -Tag 'Scoop' {
    BeforeAll {
        $tokenVars = 'SCOOP_GH_TOKEN', 'GH_TOKEN', 'GITHUB_TOKEN'
        # Stand-in for the GitHub CLI, so a real 'gh' is never invoked and Mock has something to replace
        function gh { 'gho_realCliMustNotRun' }

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
        Remove-Variable -Name ghCliToken, ghCliTokenProbed -Scope Script -ErrorAction Ignore
    }

    It 'should prefer $env:SCOOP_GH_TOKEN over every other source' {
        Mock get_config { 'from_config' }
        $env:SCOOP_GH_TOKEN = 'from_scoop_env'
        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should -Be 'from_scoop_env'
        Should -Invoke gh -Exactly -Times 0
    }

    It 'should prefer the config over the environment and the GitHub CLI' {
        Mock get_config { 'from_config' }
        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should -Be 'from_config'
        Should -Invoke gh -Exactly -Times 0
    }

    It 'should use $env:GH_TOKEN and $env:GITHUB_TOKEN before the GitHub CLI' {
        Mock get_config { 'ask-gh' }
        $env:GITHUB_TOKEN = 'from_github_env'
        Get-GitHubToken | Should -Be 'from_github_env'

        $env:GH_TOKEN = 'from_gh_env'
        Get-GitHubToken | Should -Be 'from_gh_env'

        Should -Invoke gh -Exactly -Times 0
    }

    It 'should not query the GitHub CLI unless gh_token is set to ask-gh' {
        Get-GitHubToken | Should -BeNullOrEmpty
        Should -Invoke gh -Exactly -Times 0
    }

    It 'should never return the ask-gh sentinel as a token' {
        Mock get_config { 'ask-gh' }
        Mock Test-CommandAvailable { $false }
        Get-GitHubToken | Should -BeNullOrEmpty
    }

    It 'should query the GitHub CLI when gh_token is set to ask-gh' {
        Mock get_config { 'ask-gh' }
        Get-GitHubToken | Should -Be 'gho_FROM_CLI'
        Should -Invoke gh -Exactly -Times 1
    }

    It 'should ask the GitHub CLI for the github.com token' {
        Mock get_config { 'ask-gh' }
        Get-GitHubToken | Should -Be 'gho_FROM_CLI'
        Should -Invoke gh -Exactly -Times 1 -ParameterFilter {
            ($args -join ' ') -eq 'auth token --hostname github.com'
        }
    }

    It 'should query the GitHub CLI at most once per process' {
        Mock get_config { 'ask-gh' }
        Get-GitHubToken | Should -Be 'gho_FROM_CLI'
        Get-GitHubToken | Should -Be 'gho_FROM_CLI'
        Get-GitHubToken | Should -Be 'gho_FROM_CLI'
        Should -Invoke gh -Exactly -Times 1
    }

    It 'should not query the GitHub CLI if it is not installed' {
        Mock get_config { 'ask-gh' }
        Mock Test-CommandAvailable { $false }
        Get-GitHubToken | Should -BeNullOrEmpty
        Should -Invoke gh -Exactly -Times 0
    }

    It 'should return nothing if the GitHub CLI is not logged in' {
        Mock get_config { 'ask-gh' }
        Mock gh { }
        Get-GitHubToken | Should -BeNullOrEmpty
    }

    It 'should return nothing if the GitHub CLI fails' {
        Mock get_config { 'ask-gh' }
        Mock gh { throw 'gh: could not read token' }
        Get-GitHubToken | Should -BeNullOrEmpty
    }

    It 'should not retry the GitHub CLI after a failed probe' {
        Mock get_config { 'ask-gh' }
        Mock gh { }
        Get-GitHubToken | Should -BeNullOrEmpty
        Get-GitHubToken | Should -BeNullOrEmpty
        Should -Invoke gh -Exactly -Times 1
    }

    # Callers reached from a user's own session are not shielded by the 'Set-StrictMode -Off'
    # in bin/scoop.ps1 -- bin/checkver.ps1 and lib/autoupdate.ps1 both call this directly
    It 'tolerates StrictMode when no token source is set' {
        # Unset sources are $null, and StrictMode turns the property access that filters
        # them into an error, which only becomes terminating under $ErrorActionPreference
        { & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } } | Should -Not -Throw
    }

    It 'tolerates StrictMode on the ask-gh path' {
        # The probe cache is read before it is ever assigned
        Mock get_config { 'ask-gh' }
        { & { Set-StrictMode -Version Latest; Get-GitHubToken } } | Should -Not -Throw
        { & { Set-StrictMode -Version Latest; $ErrorActionPreference = 'Stop'; Get-GitHubToken } } | Should -Not -Throw
    }
}
