. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\unix.ps1"

$isUnix = is_unix

describe "extract_zip" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "decompress"
    }

    function test-unzip($from) {
        $to = strip_ext $from

        if(is_unix) {
            extract_zip ($from -replace '\\', '/') ($to -replace '\\', '/')
        } else {
            extract_zip ($from -replace '/', '\') ($to -replace '/', '\')
        }

        $to
    }

    context "zip file is small in size" {
        $small = "$working_dir\small.zip"
        $small | should -exist

        it "unzips file which is small in size" -skip:$isUnix {
            # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
            # `$to = test-unzip $small` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
            $to = ([string](test-unzip $small)).trimStart()

            $to | should -not -match '^\s'
            $to | should -not -benullorempty

            $to | should -exist

            # these don't work for some reason on appveyor
            #join-path $to "empty" | should -exist
            #(gci $to).count | should -be 1
        }
    }
}
