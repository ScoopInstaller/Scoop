# todo
Describe -Skip 'Show status and check for new app versions' -Tag 'Scoop' {
    # scoop-status.ps1 is not structured in a way that makes this easy to test
    # todo: refactor scoop-status.ps1's loop bodies to functions for easier testing
    It 'throws when Global or User appdir is empty or does not exist' -Skip { }
}

# todo: add bucket fixtures for CI tests
Describe 'Test-UpdateStatus' -Tag 'Scoop' -Skip:($env:CI -eq $true) {
    BeforeAll {
        . "$PSScriptRoot/../libexec/scoop-status.ps1"
    }
    # todo
    It -Skip 'should return $true if $commits is falsy' {}
    # todo
    It -Skip 'should return $false if $commits is truthy' {}
    It 'should return $true if "$repopath\.git`" does not exist' {
        function makeTmpDir {
            [OutputType([System.IO.DirectoryInfo])]
            Param ()

            [string] $tmpDirPath = Join-Path $env:TEMP $(New-Guid)

            while (Test-Path $tmpDirPath) {
                $tmpDirPath = Join-Path $env:TEMP $(New-Guid)
            }

            return (New-Item $tmpDirPath -ItemType Directory)
        }
        [System.IO.DirectoryInfo] $emptyDir = makeTmpDir
        Test-UpdateStatus $emptyDir.FullName | Should -Be $true
    }
}
