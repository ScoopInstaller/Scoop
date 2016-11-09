# list manifests which do not specify a checkver regex
param($dir)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

# output app names without checkver
gci $dir "*.json" | % {
    $json = parse_json "$dir\$_"
    if(!$json.checkver) {
        write-host (strip_ext $_)
    }
}
