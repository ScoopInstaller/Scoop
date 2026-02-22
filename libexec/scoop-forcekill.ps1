# Usage: scoop forcekill <apps>
# Summary: Force close apps before updating
# Help: To mark a user-scoped app to force close:
#      scoop forcekill <app>
#
# To mark a global app to force close:
#      scoop forcekill -g <app>
#
# To explicitly define services to stop:
#      scoop forcekill <app> --service <servicename>
#
# Options:
#   -g, --global  Force close globally installed apps
#   -s, --service Services to stop (comma separated)

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\install.ps1"

$opt, $apps, $err = getopt $args 'g' 'global', 'service='
if ($err) { "scoop forcekill: $err"; exit 1 }

$global = $opt.g -or $opt.global

if (!$apps) {
    my_usage
    exit 1
}

if ($global -and !(is_admin)) {
    error 'You need admin rights to mark a global app for forcekill.'
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
        error "Failed to configure forcekill for '$app'."
        continue
    }
    $install = @{}
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name)) }
    
    $install.forcekill = $true

    if ($opt.service) {
        $services = $opt.service -split ',' | ForEach-Object { $_.Trim() }
        $install.forcekill_services = @($services)
    }

    save_install_info $install $dir
    success "$app is now marked to force close on update."
}

exit $exitcode
