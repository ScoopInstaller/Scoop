. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

describe "manifest-validation" {
    $bucketdir = "$psscriptroot\..\bucket\"
    $manifest_files = gci $bucketdir *.json

    $manifest_files | % {
        it "test validity of $_" {
            $manifest = parse_json $_.fullname

            $url = arch_specific "url" $manifest "32bit"
            if(!$url) {
                $url = arch_specific "url" $manifest "64bit"
            }

            $url | should not benullorempty
            $manifest | should not benullorempty
            $manifest.version | should not benullorempty
        }
    }
}

describe "parse_json" {
    beforeall {
        $working_dir = setup_working "parse_json"
    }

    context "json is invalid" {
        it "fails with invalid json" {
            { parse_json "$working_dir\wget.json" } | should throw
        }
    }
}
