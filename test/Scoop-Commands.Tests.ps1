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
        New-Item $alias_script -Type File -Force
        Test-Path $alias_script | Should-BeTrue

        { add_alias 'rm' '"test"' } | Should-Throw "*already exists in shims directory*"
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

    It 'Creates an alias whose name contains a wildcard character' {
        $look_alike = "$shimdir\scoop-bracket.ps1"
        $alias_script = "$shimdir\scoop-br[a]cket.ps1"
        New-Item $look_alike -Type File -Force

        add_alias 'br[a]cket' '"hello"'

        Test-Path -LiteralPath $alias_script | Should-BeTrue
    }

    It 'Removes an alias whose name contains a wildcard character' {
        $look_alike = "$shimdir\scoop-bracket.ps1"
        $alias_script = "$shimdir\scoop-br[a]cket.ps1"
        New-Item $look_alike -Type File -Force
        New-Item $alias_script -Type File -Force
        Mock get_config { @(@{'br[a]cket' = 'scoop-br[a]cket' }) }
        Mock info {}

        rm_alias 'br[a]cket'

        Test-Path -LiteralPath $alias_script | Should-BeFalse
        Test-Path -LiteralPath $look_alike | Should-BeTrue
    }
}
