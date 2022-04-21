. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\unix.ps1"

$isUnix = is_unix

Describe 'ensure_architecture' -Tag 'Scoop' {
    It 'should keep correct architectures' {
        ensure_architecture '32bit' | Should -Be '32bit'
        ensure_architecture '32' | Should -Be '32bit'
        ensure_architecture 'x86' | Should -Be '32bit'
        ensure_architecture 'X86' | Should -Be '32bit'
        ensure_architecture 'i386' | Should -Be '32bit'
        ensure_architecture '386' | Should -Be '32bit'
        ensure_architecture 'i686' | Should -Be '32bit'

        ensure_architecture '64bit' | Should -Be '64bit'
        ensure_architecture '64' | Should -Be '64bit'
        ensure_architecture 'x64' | Should -Be '64bit'
        ensure_architecture 'X64' | Should -Be '64bit'
        ensure_architecture 'amd64' | Should -Be '64bit'
        ensure_architecture 'AMD64' | Should -Be '64bit'
        ensure_architecture 'x86_64' | Should -Be '64bit'
        ensure_architecture 'x86-64' | Should -Be '64bit'
    }

    It 'should fallback to the default architecture on empty input' {
        ensure_architecture '' | Should -Be $(default_architecture)
        ensure_architecture $null | Should -Be $(default_architecture)
    }

    It 'should show an error with an invalid architecture' {
        { ensure_architecture 'PPC' } | Should -Throw
        { ensure_architecture 'PPC' } | Should -Throw "Invalid architecture: 'ppc'"
    }
}

Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should -Be 'foobar'
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

Describe 'is_in_dir' -Tag 'Scoop' {
    It 'should work correctly' -Skip:$isUnix {
        is_in_dir 'C:\test' 'C:\foo' | Should -BeFalse
        is_in_dir 'C:\test' 'C:\test\foo\baz.zip' | Should -BeTrue

        is_in_dir 'test' "$PSScriptRoot" | Should -BeTrue
        is_in_dir "$PSScriptRoot\..\" "$PSScriptRoot" | Should -BeFalse
    }
}

Describe 'env add and remove path' -Tag 'Scoop' {
    # test data
    $manifest = @{
        'env_add_path' = @('foo', 'bar')
    }
    $testdir = Join-Path $PSScriptRoot 'path-test-directory'
    $global = $false

    # store the original path to prevent leakage of tests
    $origPath = $env:PATH

    It 'should concat the correct path' -Skip:$isUnix {
        Mock add_first_in_path {}
        Mock remove_from_path {}

        # adding
        env_add_path $manifest $testdir $global
        Assert-MockCalled add_first_in_path -Times 1 -ParameterFilter { $dir -like "$testdir\foo" }
        Assert-MockCalled add_first_in_path -Times 1 -ParameterFilter { $dir -like "$testdir\bar" }

        env_rm_path $manifest $testdir $global
        Assert-MockCalled remove_from_path -Times 1 -ParameterFilter { $dir -like "$testdir\foo" }
        Assert-MockCalled remove_from_path -Times 1 -ParameterFilter { $dir -like "$testdir\bar" }
    }
}

Describe 'shim_def' -Tag 'Scoop' {
    It 'should use strings correctly' {
        $target, $name, $shimArgs = shim_def 'command.exe'
        $target | Should -Be 'command.exe'
        $name | Should -Be 'command'
        $shimArgs | Should -BeNullOrEmpty
    }

    It 'should expand the array correctly' {
        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar')
        $target | Should -Be 'foo.exe'
        $name | Should -Be 'bar'
        $shimArgs | Should -BeNullOrEmpty

        $target, $name, $shimArgs = shim_def @('foo.exe', 'bar', '--test')
        $target | Should -Be 'foo.exe'
        $name | Should -Be 'bar'
        $shimArgs | Should -Be '--test'
    }
}

Describe 'persist_def' -Tag 'Scoop' {
    It 'parses string correctly' {
        $source, $target = persist_def 'test'
        $source | Should -Be 'test'
        $target | Should -Be 'test'
    }

    It 'should handle sub-folder' {
        $source, $target = persist_def 'foo/bar'
        $source | Should -Be 'foo/bar'
        $target | Should -Be 'foo/bar'
    }

    It 'should handle arrays' {
        # both specified
        $source, $target = persist_def @('foo', 'bar')
        $source | Should -Be 'foo'
        $target | Should -Be 'bar'

        # only first specified
        $source, $target = persist_def @('foo')
        $source | Should -Be 'foo'
        $target | Should -Be 'foo'

        # null value specified
        $source, $target = persist_def @('foo', $null)
        $source | Should -Be 'foo'
        $target | Should -Be 'foo'
    }
}

Describe 'compute_hash' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working 'manifest'
    }

    It 'computes MD5 correctly' {
        compute_hash (Join-Path "$working_dir" 'invalid_wget.json') 'md5' | Should -Be 'cf229eecc201063e32b436e73b71deba'
        compute_hash (Join-Path "$working_dir" 'wget.json') 'md5' | Should -Be '57c397fd5092cbd6a8b4df56be2551ab'
        compute_hash (Join-Path "$working_dir" 'broken_schema.json') 'md5' | Should -Be '0427c7f4edc33d6d336db98fc160beb0'
        compute_hash (Join-Path "$working_dir" 'broken_wget.json') 'md5' | Should -Be '30a7d4d3f64cb7a800d96c0f2ccec87f'
    }

    It 'computes SHA-1 correctly' {
        compute_hash (Join-Path "$working_dir" 'invalid_wget.json') 'sha1' | Should -Be '33ae44df8feed86cdc8f544234029fb28280c3c5'
        compute_hash (Join-Path "$working_dir" 'wget.json') 'sha1' | Should -Be '98bfacb887da8cd05d3a1162f89d90173294be55'
        compute_hash (Join-Path "$working_dir" 'broken_schema.json') 'sha1' | Should -Be '6dcd64f8ce7a3ae6bbc3dc2288b7cb202dbfa3c8'
        compute_hash (Join-Path "$working_dir" 'broken_wget.json') 'sha1' | Should -Be '60b5b1d5bcb4193d19aeab265eab0bb9b0c46c8f'
    }

    It 'computes SHA-256 correctly' {
        compute_hash (Join-Path "$working_dir" 'invalid_wget.json') 'sha256' | Should -Be '1a92ef57c5f3cecba74015ae8e92fc3f2dbe141f9d171c3a06f98645a522d58c'
        compute_hash (Join-Path "$working_dir" 'wget.json') 'sha256' | Should -Be '31d6d0953d4e95f0a42080acd61a8c2f92bc90cae324c0d6d2301a974c15f62f'
        compute_hash (Join-Path "$working_dir" 'broken_schema.json') 'sha256' | Should -Be 'f3e5082e366006c317d9426e590623254cb1ce23d4f70165afed340b03ce333b'
        compute_hash (Join-Path "$working_dir" 'broken_wget.json') 'sha256' | Should -Be 'da658987c3902658c6e754bfa6546dfd084aaa2c3ae25f1fd8aa4645bc9cae24'
    }

    It 'computes SHA-512 correctly' {
        compute_hash (Join-Path "$working_dir" 'invalid_wget.json') 'sha512' | Should -Be '7a7b82ec17547f5ec13dc614a8cec919e897e6c344a6ce7d71205d6f1c3aed276c7b15cbc69acac8207f72417993299cef36884e1915d56758ea09efa2259870'
        compute_hash (Join-Path "$working_dir" 'wget.json') 'sha512' | Should -Be '216ebf07bb77062b51420f0f5eb6b7a94d9623d1d41d36c833436058f41e39898f2aa48d7020711c0d8765d02b87ac2e6810f3f502636a6e6f47dc4b9aa02d17'
        compute_hash (Join-Path "$working_dir" 'broken_schema.json') 'sha512' | Should -Be '8d3f5617517e61c33275eafea4b166f0a245ec229c40dea436173c354786bad72e4fd9d662f6ac2b9f3dd375c00815a07f10e12975eec1b12da7ba7db10f9c14'
        compute_hash (Join-Path "$working_dir" 'broken_wget.json') 'sha512' | Should -Be '7b16a714491e91cc6daa5f90e700547fac4d62e1fcec8c4b78f5a2386e04e68a8ed68f27503ece9555904a047df8050b3f12b4f779c05b1e4d0156e6e2d8fdbb'
    }
}
