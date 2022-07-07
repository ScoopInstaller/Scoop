# Usage: scoop depends <app>
# Summary: List dependencies for an app, in the order they'll be installed

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'
. "$PSScriptRoot\..\lib\manifest.ps1" # 'default_architecture'

$opt, $apps, $err = getopt $args 'a:' 'arch='
$app = $apps[0]

if(!$app) { error '<app> missing'; my_usage; exit 1 }

$architecture = default_architecture
try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

$deps = @()
Get-Dependency $app $architecture | ForEach-Object {
    $dep = [ordered]@{}
    $dep.Source, $dep.Name = $_ -split '/'
    $deps += [PSCustomObject]$dep
}
$deps

exit 0
