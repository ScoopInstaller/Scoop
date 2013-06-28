# Usage: scoop list
# Summary: List installed apps
# Help: Lists all installed apps

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

$apps = installed_apps

if($apps) {
    echo "Installed apps:
"
    $apps
    ""
} else { "there aren't any apps installed" }

exit 0
