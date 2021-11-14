# Usage: scoop hold <apps>
# Summary: Hold an app to disable updates

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
    $install.hold = $true
    save_install_info $install $dir
    success "$app is now held and can not be updated anymore."
}

exit $exitcode
