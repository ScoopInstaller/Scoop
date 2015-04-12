. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

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

        it "unzips file with zero bytes without error" {
            $to = test-unzip $zerobyte

            $to | should exist
            (gci $to).count | should be 0
        }
    }

    context "zip file is small in size" {
        $small = "$working_dir\small.zip"
        
        it "unzips file which is small in size" {
            $to = test-unzip $small

            $to | should exist

            # these don't work for some reason on appveyor
            #join-path $to "empty" | should exist
            #(gci $to).count | should be 1
        }
    }
}

describe "shim" {
    $working_dir = setup_working "shim"
    $shimdir = shimdir $false

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
    $working_dir = setup_working "shim"
    $shimdir = shimdir $false

    it "removes shim from path" {
        shim "$working_dir\shim-test.ps1" $false "shim-test"

        rm_shim "shim-test" $shimdir

        { get-command "shim-test" -ea stop } | should throw
        { get-command "shim-test.ps1" -ea stop } | should throw
        { get-command "shim-test.cmd" -ea stop } | should throw
        { shim-test } | should throw
    }
}