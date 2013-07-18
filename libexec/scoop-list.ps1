# Usage: scoop list
# Summary: List installed apps
# Help: Lists all installed apps

. "$psscriptroot\..\lib\core.ps1"
. (relpath '..\lib\versions.ps1')
. (relpath '..\lib\manifest.ps1')

$apps = installed_apps

if($apps) {
    echo "Installed apps:
"
    $apps | % {
        "$_ ($(latest_version $_))"
    }
    ""
} else { "there aren't any apps installed" }

exit 0
