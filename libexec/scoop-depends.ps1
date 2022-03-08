# Usage: scoop depends <app>
# Summary: List dependencies for an app

. "$PSScriptRoot\..\lib\depends.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

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

$deps = @(Get-Dependency $app $architecture) -ne $app
if($deps) {
    $deps[($deps.length - 1)..0]
}

exit 0
