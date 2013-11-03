# usage: scoop depends <app>
# summary: List dependencies for an app

. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\decompress.ps1"

$opt, $app, $err = getopt $args 'a:' 'arch='
$architecture = ensure_architecture ($opt.a + $opt.architecture)

deps $app $architecture