. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\unix.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\config.ps1"

$isUnix = is_unix

function install_app_ci($app, $architecture) {
    $manifest = manifest $app
    $version = $manifest.version
    $dir = ensure (versiondir $app $version)
    $fname = dl_urls $app $version $manifest $null $architecture $dir
    $dir = link_current $dir
    success "'$app' ($version) was installed successfully!"
}

describe "extract_zip" -Tag 'Scoop', 'Decompress' {
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
