# Usage: scoop unhold <app>
# Summary: Unhold an app to enable updates
# Help: To unhold a user-scoped app:
#      scoop unhold <app>
#
# To unhold a global app:
#      scoop unhold -g <app>
#
# Options:
#   -g, --global  Unhold globally installed apps

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'save_install_info' (indirectly)
. "$PSScriptRoot\..\lib\manifest.ps1" # 'install_info' 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { "scoop unhold: $err"; exit 1 }

$global = $opt.g -or $opt.global

if (!$apps) {
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to unhold a global app.'
    exit 1
}

$apps | ForEach-Object {
    $app = $_

    if (!(installed $app $global)) {
        if ($global) {
            error "'$app' is not installed globally."
        } else {
            error "'$app' is not installed."
        }
        return
    }

    if (get_config NO_JUNCTIONS) {
        $version = Select-CurrentVersion -App $app -Global:$global
    } else {
        $version = 'current'
    }
    $dir = versiondir $app $version $global
    $json = install_info $app $version $global
    $install = @{}
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }
    $install.hold = $null
    save_install_info $install $dir
    success "$app is no longer held and can be updated again."
}

exit $exitcode
