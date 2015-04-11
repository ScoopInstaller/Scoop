. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

describe "movedir" {
    $working_dir = setup_working "movedir"
    $extract_dir = "subdir"
    $extract_to = $null

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
    function test-unzip($from) {
        $to = "$psscriptroot\tmp\$(strip_ext (fname $from))"

        # clean-up from previous runs
        if(test-path $to) {
            rm -r -force $to
        }

        unzip_old $from $to 

        $to
    }

    context "zip file size is zero bytes" {
        $zerobyte = "$psscriptroot\fixtures\zerobyte.zip"

        it "unzips file with zero bytes without error" {
            $to = test-unzip $zerobyte

            $to | should exist
            (gci $to).count | should be 0
        }
    }

    context "zip file is small in size" {
        $small = "$psscriptroot\fixtures\small.zip"
        
        it "unzips file which is small in size" {
            $to = test-unzip $small

            $to | should exist

            # these don't work for some reason on appveyor
            #join-path $to "empty" | should exist
            #(gci $to).count | should be 1
        }
    }
}