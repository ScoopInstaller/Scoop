BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\help.ps1"
    . "$PSScriptRoot\..\libexec\scoop-alias.ps1" | Out-Null
}

Describe 'Manipulate Alias' -Tag 'Scoop' {
    BeforeAll {
        Mock shimdir { "$TestDrive\shims" }
        Mock set_config { }
        Mock get_config { @{} }

        $shimdir = shimdir
        ensure $shimdir
    }

    It 'Creates a new alias if alias doesn''t exist' {
        $alias_file = "$shimdir\scoop-rm.ps1"
        $alias_file | Should -Not -Exist

        add_alias 'rm' '"hello, world!"'
        & $alias_file | Should -Be 'hello, world!'
    }

    It 'Does not change existing alias if alias exists' {
        $alias_file = "$shimdir\scoop-rm.ps1"
        New-Item $alias_file -Type File -Force
        $alias_file | Should -Exist

        add_alias 'rm' 'test'
        & $alias_file | Should -Not -Be 'test'
    }

    It 'Removes an existing alias' {
        $alias_file = "$shimdir\scoop-rm.ps1"
        add_alias 'rm' '"hello, world!"'

        $alias_file | Should -Exist
        Mock get_config { @(@{'rm' = 'scoop-rm' }) }

        rm_alias 'rm'
        $alias_file | Should -Not -Exist
    }
}
