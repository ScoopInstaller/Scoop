BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
}

Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should-Be 'foobar'
    }
}

Describe 'env add and remove path' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        # test data
        $manifest = @{
            'env_add_path' = @('foo', 'bar', '.', '..')
        }
        $testdir = Join-Path $PSScriptRoot 'path-test-directory'
        $global = $false
    }

    It 'should concat the correct path' {
        Mock Add-Path {}
        Mock Remove-Path {}

        # adding
        env_add_path $manifest $testdir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }

        env_rm_path $manifest $testdir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Remove-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }
    }
}

Describe 'shim_def' -Tag 'Scoop' {
    It 'should use strings correctly' {
        $target, $name, $shimArgs = shim_def 'command.exe'
        $target | Should-Be 'command.exe'
        $name | Should-Be 'command'
        $shimArgs | Should-BeNull
    }

    It 'should expand the array correctly' {
        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar')
        $target | Should-Be 'foo.exe'
        $name | Should-Be 'bar'
        $shimArgs | Should-BeNull

        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar', '--test')
        $target | Should-Be 'foo.exe'
        $name | Should-Be 'bar'
        $shimArgs | Should-Be '--test'
    }
}

Describe 'persist_def' -Tag 'Scoop' {
    It 'parses string correctly' {
        $source, $target = persist_def 'test'
        $source | Should-Be 'test'
        $target | Should-Be 'test'
    }

    It 'should handle sub-folder' {
        $source, $target = persist_def 'foo/bar'
        $source | Should-Be 'foo/bar'
        $target | Should-Be 'foo/bar'
    }

    It 'should handle arrays' {
        # both specified
        $source, $target = persist_def @('foo', 'bar')
        $source | Should-Be 'foo'
        $target | Should-Be 'bar'

        # only first specified
        $source, $target = persist_def @('foo')
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'

        # null value specified
        $source, $target = persist_def @('foo', $null)
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'
    }
}

Describe 'shim names with wildcard characters' -Tag 'Scoop', 'Windows' {
    It 'treats a target file name literally when creating a shim' {
        Mock shim {}
        Mock abort -MockWith { throw $msg }

        $dir = Join-Path $TestDrive 'br[a]cket'
        $null = [IO.Directory]::CreateDirectory($dir)
        [IO.File]::WriteAllText("$dir\br[a]cket.exe", '')

        create_shims @{ bin = 'br[a]cket.exe' } $dir $false $null

        Should-Invoke -CommandName shim -Times 1 -ParameterFilter { $Path -eq "$dir\br[a]cket.exe" }
    }

    It 'shims a target whose name contains a wildcard character' {
        Mock abort -MockWith { throw $msg }
        # the body lookup follows the machine's config, so pin it to the bundled body
        Mock get_shim_path { Join-Path $PSScriptRoot '..\supporting\shims\scoopcs\shim.exe' }
        # the shims of the machine and its path stay untouched
        $shimdir = Join-Path $TestDrive 'shims-wildcard'
        Mock shimdir { $shimdir }
        Mock Add-Path {}

        $dir = Join-Path $TestDrive 'br[a]cket-shim'
        $null = [IO.Directory]::CreateDirectory($dir)
        [IO.File]::WriteAllText("$dir\br[a]cket.exe", 'not a real binary')

        try {
            create_shims @{ bin = 'br[a]cket.exe' } $dir $false $null

            Test-Path -LiteralPath "$shimdir\br[a]cket.exe" | Should-Be $true
        } finally {
            rm_shim 'br[a]cket' $shimdir
        }
    }

    It 'reads the app name from a shim whose name contains a wildcard character' {
        $appsRoot = Join-Path $TestDrive 'apps'
        $null = [IO.Directory]::CreateDirectory($appsRoot)
        Mock appsdir { $appsRoot }

        $shimdir = Join-Path $TestDrive 'shims-appname'
        $null = [IO.Directory]::CreateDirectory($shimdir)
        [IO.File]::WriteAllText("$shimdir\br[a]cket.shim", "path = $appsRoot\br[a]cket\current\br[a]cket.exe")

        $Error.Clear()
        get_app_name_from_shim "$shimdir\br[a]cket.shim" | Should-Be 'br[a]cket'
        $Error.Count | Should-Be 0
    }

    It 'removes a shim literally without touching a wildcard look-alike' {
        $shimdir = Join-Path $TestDrive 'shims'
        $null = [IO.Directory]::CreateDirectory($shimdir)
        [IO.File]::WriteAllText("$shimdir\br[a]cket.shim", '')
        [IO.File]::WriteAllText("$shimdir\bracket.shim", '')

        rm_shim 'br[a]cket' $shimdir

        Test-Path -LiteralPath "$shimdir\br[a]cket.shim" | Should-BeFalse
        Test-Path -LiteralPath "$shimdir\bracket.shim" | Should-BeTrue
    }

    It 'aborts with a friendly message when the shim target is not on PATH' {
        Mock shim {}
        $aborted = @{}
        Mock abort { $aborted.Message = $msg; throw $msg }

        $dir = Join-Path $TestDrive 'missing'
        $null = [IO.Directory]::CreateDirectory($dir)

        # A caller with $ErrorActionPreference = 'Stop' must still reach the abort below, not a raw Get-Command error.
        { $ErrorActionPreference = 'Stop'; create_shims @{ bin = 'scoop-nonexistent-command' } $dir $false $null } |
            Should-Throw

        $aborted.Message | Should-Be "Can't shim 'scoop-nonexistent-command': File doesn't exist."
    }


    It 'resolves a bin target from $original_dir when it is not under $dir or on PATH' {
        Mock shim {}
        Mock abort -MockWith { throw $msg }

        $dir = Join-Path $TestDrive 'linked-install'
        $originalDir = Join-Path $TestDrive 'original-install'
        $null = [IO.Directory]::CreateDirectory($dir)
        $null = [IO.Directory]::CreateDirectory($originalDir)
        [IO.File]::WriteAllText("$originalDir\scoop-bare-target.exe", '')

        # create_shims reads $original_dir from the caller's scope, as create_startmenu_shortcuts does.
        & {
            $original_dir = $originalDir
            create_shims @{ bin = 'scoop-bare-target.exe' } $dir $false $null
        }

        Should-Invoke -CommandName shim -Times 1 -ParameterFilter { $Path -eq "$originalDir\scoop-bare-target.exe" }
    }


    It 'narrows the PATH lookup to applications and external scripts' {
        Mock shim {}
        $seen = @{}
        Mock Get-CommandLiteral {
            $seen.CommandType = $CommandType
            [pscustomobject] @{ Source = "$TestDrive\bin-target.ps1" }
        }

        $dir = Join-Path $TestDrive 'narrowed-path'
        $null = [IO.Directory]::CreateDirectory($dir)

        create_shims @{ bin = 'bin-target.ps1' } $dir $false $null

        $types = "$($seen.CommandType)"
        ($types -match 'Application') | Should-BeTrue
        ($types -match 'ExternalScript') | Should-BeTrue
        Should-Invoke -CommandName shim -Times 1 -ParameterFilter { $Path -eq "$TestDrive\bin-target.ps1" }
    }

    It 'picks one path when the bin name resolves to several commands' {
        $seen = @{}
        Mock shim { $seen.Path = $Path }

        $pathDir = Join-Path $TestDrive 'multi-command'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        'scoop-multi-target.ps1', 'scoop-multi-target.cmd', 'scoop-multi-target.exe' | ForEach-Object {
            [IO.File]::WriteAllText("$pathDir\$_", '')
        }

        $oldPath = $env:PATH
        $env:PATH = "$pathDir;$env:PATH"
        try {
            # develop's expression against the same PATH, to prove the narrowed lookup picks the same command
            $expected = (Get-Command 'scoop-multi-target').Source

            $dir = Join-Path $TestDrive 'multi-command-install'
            $null = [IO.Directory]::CreateDirectory($dir)
            create_shims @{ bin = 'scoop-multi-target' } $dir $false $null

            $seen.Path -is [string] | Should-BeTrue
            $seen.Path | Should-Be $expected
            Should-Invoke -CommandName shim -Times 1
        } finally {
            $env:PATH = $oldPath
        }
    }

    It 'resolves a bin target with wildcard characters from PATH to the literal file' {
        Mock shim {}
        Mock abort -MockWith { throw $msg }

        $pathDir = Join-Path $TestDrive 'literal-path'
        $null = [IO.Directory]::CreateDirectory($pathDir)
        'br[a]cket.exe', 'bracket.exe' | ForEach-Object { [IO.File]::WriteAllText("$pathDir\$_", '') }

        $oldPath = $env:PATH
        $env:PATH = "$pathDir;$env:PATH"
        try {
            $dir = Join-Path $TestDrive 'literal-path-install'
            $null = [IO.Directory]::CreateDirectory($dir)
            create_shims @{ bin = 'br[a]cket.exe' } $dir $false $null
        } finally {
            $env:PATH = $oldPath
        }

        Should-Invoke -CommandName shim -Times 1 -ParameterFilter { $Path -eq "$pathDir\br[a]cket.exe" }
    }


}
