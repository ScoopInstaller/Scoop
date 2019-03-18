# Usage: scoop depends <app>
# Summary: List dependencies for an app

. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'a:' 'arch='
$app = $apps[0]

if(!$app) { error '<app> missing'; my_usage; exit 1 }

$architecture = default_architecture
try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

$deps = @(deps $app $architecture)
if($deps) {
    $deps[($deps.length - 1)..0]
}

exit 0
