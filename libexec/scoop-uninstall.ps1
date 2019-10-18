# Usage: scoop uninstall <app> [options]
# Summary: Uninstall an app
# Help: e.g. scoop uninstall git
#
# Options:
#   -g, --global   Uninstall a globally installed app
#   -p, --purge    Remove all persistent data

'core', 'manifest', 'help', 'install', 'shortcuts', 'psmodules', 'versions', 'getopt' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}
Join-Path $PSScriptRoot '..\lib\Uninstall.psm1' | Import-Module

reset_aliases

# options
$opt, $apps, $err = getopt $args 'gp' 'global', 'purge'

if ($err) {
    error "scoop uninstall: $err"
    exit 1
}

$global = $opt.g -or $opt.global
$purge = $opt.p -or $opt.purge

if (!$apps) {
    error '<app> missing'
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to uninstall global apps.'
    exit 1
}

if ($apps -eq 'scoop') {
    & "$PSScriptRoot\..\bin\uninstall.ps1" $global $purge
    exit
}

$apps = Confirm-InstallationStatus $apps -Global:$global
if (!$apps) { exit 0 }

:app_loop foreach ($_ in $apps) {
    ($app, $global) = $_

    $result = Uninstall-ScoopApplication -App $app -Global:$global -Purge:$purge -Older
    if ($result -eq $false) { continue }

    success "'$app' was uninstalled."
}

exit 0
