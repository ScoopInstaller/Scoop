# Usage: scoop depends <app>
# Summary: List dependencies for an app, in the order they'll be installed

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest' (indirectly)
. "$PSScriptRoot\..\lib\download.ps1" # 'Get-UserAgent'

$opt, $apps, $err = getopt $args 'a:' 'arch='
$app = $apps[0]

if(!$app) { error '<app> missing'; my_usage; exit 1 }

$architecture = Get-DefaultArchitecture
try {
    $architecture = Format-ArchitectureString ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

$deps = @()
Get-Dependency $app $architecture | ForEach-Object {
    $dep = [ordered]@{}

    $app, $null, $bucket, $url = Get-Manifest $_
    if (!$url) {
        $bucket, $app = $_ -split '/'
    }
    $dep.Source = if ($url) { $url } else { $bucket }
    $dep.Name = $app

    $deps += [PSCustomObject]$dep
}
$deps

exit 0
