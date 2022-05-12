# Usage: scoop prefix <app>
# Summary: Returns the path to the specified app
param($app)

. "$PSScriptRoot\..\lib\versions.ps1" # 'currentdir' (indirectly)

if (!$app) {
    my_usage
    exit 1
}

$app_path = currentdir $app $false
if (!(Test-Path $app_path)) {
    $app_path = currentdir $app $true
}

if (Test-Path $app_path) {
    Write-Output $app_path
} else {
    abort "Could not find app path for '$app'."
}

exit 0
