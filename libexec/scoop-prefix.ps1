# Usage: scoop prefix <app>
# Summary: Returns the path to the specified app
param($app)

if (!$app) {
    . "$PSScriptRoot\..\lib\help.ps1"
    my_usage
    exit 1
}

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"

$app_path = currentdir $app $false
if (!(Test-Path $app_path)) {
    $app_path = currentdir $app$true
}

if (Test-Path $app_path) {
    Write-Output $app_path
} else {
    abort "Could not find app path for '$app'."
}

exit 0
