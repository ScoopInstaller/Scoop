# Usage: scoop unforcekill <apps>
# Summary: Remove force close setting from an app
# Help: To unmark a user-scoped app:
#      scoop unforcekill <app>
#
# To unmark a global app:
#      scoop unforcekill -g <app>
#
# Options:
#   -g, --global  Unmark globally installed apps

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\install.ps1"

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { "scoop unforcekill: $err"; exit 1 }

$global = $opt.g -or $opt.global

if (!$apps) {
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to unmark a global app.'
    exit 1
}

foreach ($app in $apps) {
    if (!(installed $app $global)) {
        if ($global) {
            error "'$app' is not installed globally."
        } else {
            error "'$app' is not installed."
        }
        continue
    }

    if (get_config NO_JUNCTION) {
        $version = Select-CurrentVersion -App $app -Global:$global
    } else {
        $version = 'current'
    }
    $dir = versiondir $app $version $global
    $json = install_info $app $version $global
    if (!$json) {
        error "Failed to unmark forcekill for '$app'."
        continue
    }
    $install = @{}
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }

    if (!$install.forcekill -and !$install.forcekill_services) {
        info "'$app' is not marked for forcekill."
        continue
    }
    $install.Remove('forcekill')
    $install.Remove('forcekill_services')
    save_install_info $install $dir
    success "$app is no longer marked to force close on update."
}

exit $exitcode
