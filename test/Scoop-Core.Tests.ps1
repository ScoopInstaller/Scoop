. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName

describe "movedir" {
    $extract_dir = "subdir"
    $extract_to = $null

    beforeall {
        $working_dir = setup_working "movedir"
    }

    it "moves directories with no spaces in path" {
        $dir = "$working_dir\user"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_scoop_extract\$extract_dir" | should not exist
    }

    it "moves directories with spaces in path" {
        $dir = "$working_dir\user with space"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_scoop_extract\$extract_dir" | should not exist

        # test trailing \ in from dir
        movedir "$dir\_scoop_extract\$null" "$dir\another"
        "$dir\another\test.txt" | should contain "testing"
        "$dir\_scoop_extract" | should not exist
    }

    it "moves directories with quotes in path" {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_scoop_extract\$extract_dir" | should not exist
    }
}

describe "unzip_old" {
    beforeall {
        $working_dir = setup_working "unzip_old"
    }

    function test-unzip($from) {
        $to = strip_ext $from

        unzip_old $from $to

        $to
    }

    context "zip file size is zero bytes" {
        $zerobyte = "$working_dir\zerobyte.zip"
        $zerobyte | should exist

        it "unzips file with zero bytes without error" {
            # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
            # `$to = test-unzip $zerobyte` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
            $to = ([string](test-unzip $zerobyte)).trimStart()

            $to | should not match '^\s'
            $to | should not be NullOrEmpty

            $to | should exist

            (gci $to).count | should be 0
        }
    }

    context "zip file is small in size" {
        $small = "$working_dir\small.zip"
        $small | should exist

        it "unzips file which is small in size" {
            # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
            # `$to = test-unzip $small` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
            $to = ([string](test-unzip $small)).trimStart()

            $to | should not match '^\s'
            $to | should not be NullOrEmpty

            $to | should exist

            # these don't work for some reason on appveyor
            #join-path $to "empty" | should exist
            #(gci $to).count | should be 1
        }
    }
}

describe "shim" {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "links a file onto the user's path" {
        { get-command "shim-test" -ea stop } | should throw
        { get-command "shim-test.ps1" -ea stop } | should throw
        { get-command "shim-test.cmd" -ea stop } | should throw
        { shim-test } | should throw

        shim "$working_dir\shim-test.ps1" $false "shim-test"
        { get-command "shim-test" -ea stop } | should not throw
        { get-command "shim-test.ps1" -ea stop } | should not throw
        { get-command "shim-test.cmd" -ea stop } | should not throw
        shim-test | should be "Hello, world!"
    }

    context "user with quote" {
        it "shims a file with quote in path" {
            { get-command "shim-test" -ea stop } | should throw
            { shim-test } | should throw

            shim "$working_dir\user with 'quote\shim-test.ps1" $false "shim-test"
            { get-command "shim-test" -ea stop } | should not throw
            shim-test | should be "Hello, world!"
        }
    }

    aftereach {
        rm_shim "shim-test" $shimdir
    }
}

describe "rm_shim" {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "removes shim from path" {
        shim "$working_dir\shim-test.ps1" $false "shim-test"

        rm_shim "shim-test" $shimdir

        { get-command "shim-test" -ea stop } | should throw
        { get-command "shim-test.ps1" -ea stop } | should throw
        { get-command "shim-test.cmd" -ea stop } | should throw
        { shim-test } | should throw
    }
}

describe "ensure_robocopy_in_path" {
    $shimdir = shimdir $false
    mock versiondir { $repo_dir }

    beforeall {
        reset_aliases
    }

    context "robocopy is not in path" {
        it "shims robocopy when not on path" {
            mock gcm { $false }
            gcm robocopy | should be $false

            ensure_robocopy_in_path

            "$shimdir/robocopy.ps1" | should exist
            "$shimdir/robocopy.exe" | should exist

            # clean up
            rm_shim robocopy $(shimdir $false) | out-null
        }
    }

    context "robocopy is in path" {
        it "does not shim robocopy when it is in path" {
            mock gcm { $true }
            ensure_robocopy_in_path

            "$shimdir/robocopy.ps1" | should not exist
            "$shimdir/robocopy.exe" | should not exist
        }
    }
}

describe 'sanitary_path' {
  it 'removes invalid path characters from a string' {
    $path = 'test?.json'
    $valid_path = sanitary_path $path

    $valid_path | should be "test.json"
  }
}
