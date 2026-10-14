BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\commands.ps1"
}

Describe 'Manipulate Alias' -Tag 'Scoop' {
    BeforeAll {
        Mock shimdir { "$TestDrive\shims" }
        Mock set_config {}
        Mock get_config { @{} }

        $shimdir = shimdir
        ensure $shimdir
    }

    It 'Creates a new alias if it does not exist' {
        $alias_script = "$shimdir\scoop-rm.ps1"
        Test-Path $alias_script | Should-BeFalse

        add_alias 'rm' '"hello, world!"'
        & $alias_script | Should-Be 'hello, world!'
    }

    It 'Skips an existing alias' {
        $alias_script = "$shimdir\scoop-rm.ps1"
        Mock abort {}
        New-Item $alias_script -Type File -Force
        Test-Path $alias_script | Should-BeTrue

        add_alias 'rm' '"test"'
        Should-Invoke -CommandName abort -Times 1 -ParameterFilter { $msg -eq "File 'scoop-rm.ps1' already exists in shims directory." }
    }

    It 'Removes an existing alias' {
        $alias_script = "$shimdir\scoop-rm.ps1"
        Test-Path $alias_script | Should-BeTrue
        Mock get_config { @(@{'rm' = 'scoop-rm' }) }
        Mock info {}

        rm_alias 'rm'
        Test-Path $alias_script | Should-BeFalse
        Should-Invoke -CommandName info -Times 1 -ParameterFilter { $msg -eq "Removing alias 'rm'..." }
    }
}
