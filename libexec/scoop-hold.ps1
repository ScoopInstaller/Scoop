# Usage: scoop hold <apps>
# Summary: Hold an app to disable updates
# Help: To hold a user-scoped app:
#      scoop hold <app>
#
# To hold a global app:
#      scoop hold -g <app>
#
# Options:
#   -g, --global  Hold globally installed apps

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'save_install_info' (indirectly)
. "$PSScriptRoot\..\lib\manifest.ps1" # 'install_info' 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { "scoop hold: $err"; exit 1 }

$global = $opt.g -or $opt.global

if (!$apps) {
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to hold a global app.'
    exit 1
}

$apps | ForEach-Object {
    $app = $_

    if ($app -eq 'scoop') {
        $hold_update_until = [System.DateTime]::Now.AddDays(1)
        set_config HOLD_UPDATE_UNTIL $hold_update_until.ToString('o') | Out-Null
        success "$app is now held and might not be updated until $($hold_update_until.ToLocalTime())."
        return
    }
    if (!(installed $app $global)) {
        if ($global) {
            error "'$app' is not installed globally."
        } else {
            error "'$app' is not installed."
        }
        return
    }

    if (get_config NO_JUNCTION){
        $version = Select-CurrentVersion -App $app -Global:$global
    } else {
        $version = 'current'
    }
    $dir = versiondir $app $version $global
    $json = install_info $app $version $global
    $install = @{}
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }
    $install.hold = $true
    save_install_info $install $dir
    success "$app is now held and can not be updated anymore."
}

exit $exitcode
