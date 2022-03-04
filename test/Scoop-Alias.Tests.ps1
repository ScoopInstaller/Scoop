. "$PSScriptRoot\..\libexec\scoop-alias.ps1" | Out-Null

reset_aliases

Describe 'add_alias' -Tag 'Scoop' {
    Mock shimdir { 'TestDrive:\shim' }
    Mock set_config { }
    Mock get_config { @{} }

    $shimdir = shimdir
    mkdir $shimdir

    Context "alias doesn't exist" {
        It 'creates a new alias' {
            $alias_file = "$shimdir\scoop-rm.ps1"
            $alias_file | Should -Not -Exist

            add_alias 'rm' '"hello, world!"'
            Invoke-Expression $alias_file | Should -Be 'hello, world!'
        }
    }

    Context 'alias exists' {
        It 'does not change existing alias' {
            $alias_file = "$shimdir\scoop-rm.ps1"
            New-Item $alias_file -type file
            $alias_file | Should -Exist

            add_alias 'rm' 'test'
            $alias_file | Should -FileContentMatch ''
        }
    }
}

Describe 'rm_alias' -Tag 'Scoop' {
    Mock shimdir { 'TestDrive:\shim' }
    Mock set_config { }
    Mock get_config { @{} }

    $shimdir = shimdir
    mkdir $shimdir

    Context 'alias exists' {
        It 'removes an existing alias' {
            $alias_file = "$shimdir\scoop-rm.ps1"
            add_alias 'rm' '"hello, world!"'

            $alias_file | Should -Exist
            Mock get_config { @(@{'rm' = 'scoop-rm' }) }

            rm_alias 'rm'
            $alias_file | Should -Not -Exist
        }
    }
}
