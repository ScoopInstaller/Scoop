# Usage: scoop unhold <app>
# Summary: Unhold an app to enable updates

. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

reset_aliases
$apps = $args

if(!$apps) {
    my_usage
    exit 1
}

$apps | ForEach-Object {
    $app = $_
    $global = installed $app $true

    if (!(installed $app)) {
        error "'$app' is not installed."
        return
    }

    $dir = versiondir $app 'current' $global
    $json = install_info $app 'current' $global
    $install = @{}
    $json | Get-Member -MemberType Properties | ForEach-Object { $install.Add($_.Name, $json.($_.Name))}
    $install.hold = $null
    save_install_info $install $dir
    success "$app is no longer held and can be updated again."
}

exit $exitcode
