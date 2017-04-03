. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

describe "env add and remove path" {
    # test data
    $manifest = @{
        "env_add_path" = @("foo", "bar")
    }
    $testdir = join-path $psscriptroot "path-test-directory"
    $global = $false

    # store the original path to prevent leakage of tests
    $origPath = $env:PATH

    it "should concat the correct path" {
        mock add_first_in_path {}
        mock remove_from_path {}

        # adding
        env_add_path $manifest $testdir $global
        Assert-MockCalled add_first_in_path -Times 1 -ParameterFilter {$dir -like "$testdir\foo"}
        Assert-MockCalled add_first_in_path -Times 1 -ParameterFilter {$dir -like "$testdir\bar"}

        env_rm_path $manifest $testdir $global
        Assert-MockCalled remove_from_path -Times 1 -ParameterFilter {$dir -like "$testdir\foo"}
        Assert-MockCalled remove_from_path -Times 1 -ParameterFilter {$dir -like "$testdir\bar"}
    }
}

describe 'persist_def' {
    it 'parses string correctly' {
        $source, $target = persist_def "test"
        $source | Should be "test"
        $target | Should be "test"
    }

    it 'should strip directories of source for target' {
        $source, $target = persist_def "foo/bar"
        $source | Should be "foo/bar"
        $target | Should be "bar"
    }

    it 'should handle arrays' {
        # both specified
        $source, $target = persist_def @("foo", "bar")
        $source | Should be "foo"
        $target | Should be "bar"

        # only first specified
        $source, $target = persist_def @("foo")
        $source | Should be "foo"
        $target | Should be "foo"

        # null value specified
        $source, $target = persist_def @("foo", $null)
        $source | Should be "foo"
        $target | Should be "foo"
    }
}
