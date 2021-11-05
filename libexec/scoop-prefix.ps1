# Usage: scoop prefix <app>
# Summary: Returns the path to the specified app
param($app)

if(!$app) { 
    . "$psscriptroot\..\lib\help.ps1"
    my_usage
    exit 1
}

. "$psscriptroot\..\lib\core.ps1"

$app_path = versiondir $app 'current' $false
if(!(Test-Path $app_path)) {
    $app_path = versiondir $app 'current' $true
}

if(Test-Path $app_path) {
    Write-Output $app_path
} else {
    abort "Could not find app path for '$app'."
}

exit 0
