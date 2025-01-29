# copied from scoop-status.ps1 and modified
BeforeAll {
    . "$PSScriptRoot\..\lib\manifest.ps1" # 'manifest' 'parse_json' "install_info"
    . "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
    . "$PSScriptRoot\..\lib\core.ps1" # 'versiondir'
    Import-Module "$PSScriptRoot\..\lib\core.ps1" -Function 'versiondir'

    # check if scoop needs updating
    $currentdir = versiondir 'scoop' 'current'
    $needs_update = $false
    $bucket_needs_update = $false
    $script:network_failure = $false
    $no_remotes = $args[0] -eq '-l' -or $args[0] -eq '--local'
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { $no_remotes = $true }
    $list = @()
    if (!(Get-FormatData ScoopStatus)) {
        Update-FormatData "$PSScriptRoot\..\supporting\formats\ScoopTypes.Format.ps1xml"
    }
}

# script-level content
# todo
Describe -Skip 'Show status and check for new app versions' -Tag 'Scoop' {
    # scoop-status.ps1 is not structured in a way that makes this easy to test
    # todo: refactor scoop-status.ps1's loop bodies to functions for easier testing
    It 'throws when Global or User appdir is empty or does not exist' -Skip {

    }
}

Describe 'Test-UpdateStatus' -Tag 'Scoop' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../libexec/scoop-status.ps1" -Function 'Test-UpdateStatus'
    }
    # todo
    It -Skip 'should return $true if $commits is falsy' {

    }
    # todo
    It -Skip 'should return $false if $commits is truthy' {

    }
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
