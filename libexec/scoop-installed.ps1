# Usage: scoop installed <app> [options]
# Summary: Check if an app is installed
# Help: e.g. scoop installed git
#
# Options:
#   -g, --global              Check against globally installed apps

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"


reset_aliases


$opt, $apps, $err = getopt $args 'g' 'global'
if($err) { "scoop installed: $err"; exit 1 }

$global = $opt.g -or $opt.global

if(!$apps) { 'ERROR: <app> missing'; my_usage; exit 1 }

if($global -and !(is_admin)) {
    'ERROR: you need admin rights to install global apps'; exit 1
}

return installed $apps $global