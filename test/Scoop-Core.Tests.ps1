. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\tests.ps1"

describe "movedir" {
    $working_dir = setup_working "movedir"
    $extract_dir = "subdir"
    $extract_to = $null

    it "moves directories with no spaces in path" {
        $dir = "$working_dir\user"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        gc "$dir\test.txt" | should be "this is the one"
        test-path "$dir\_scoop_extract\$extract_dir" | should be $false
    }

    it "moves directories with spaces in path" {
        $dir = "$working_dir\user with space"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        gc "$dir\test.txt" | should be "this is the one"
        test-path "$dir\_scoop_extract\$extract_dir" | should be $false   

        # test trailing \ in from dir
        movedir "$dir\_scoop_extract\$null" "$dir\another"
        gc "$dir\another\test.txt" | should be "testing"
        test-path "$dir\_scoop_extract" | should be $false
    }

    it "moves directories with quotes in path" {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_scoop_extract\$extract_dir" "$dir\$extract_to"

        gc "$dir\test.txt" | should be "this is the one"
        test-path "$dir\_scoop_extract\$extract_dir" | should be $false
    }
}