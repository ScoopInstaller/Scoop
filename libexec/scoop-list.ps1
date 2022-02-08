# Usage: scoop list [query]
# Summary: List installed apps
# Help: Lists all installed apps, or the apps matching the supplied query.
param($query)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"

reset_aliases
$def_arch = default_architecture
if (-not (Get-FormatData ScoopAppsList)) {
    Update-FormatData "$PSScriptRoot\..\supporting\formats\ScoopAppsList.Format.ps1xml"
}

$local = installed_apps $false | ForEach-Object { @{ name = $_ } }
$global = installed_apps $true | ForEach-Object { @{ name = $_; global = $true } }

$apps = @($local) + @($global)
if (-not $apps) {
    Write-Host "There aren't any apps installed."
    exit 1
}

$list = @()
Write-Host "Installed apps$(if($query) { `" matching '$query'`"}):"
$apps | Where-Object { !$query -or ($_.name -match $query) } | ForEach-Object {
    $app = $_.name
    $global = $_.global
    $item = @{ PSTypeName = 'ScoopAppsList' }
    $ver = Select-CurrentVersion -AppName $app -Global:$global
    $item.Name = $app
    $item.Version = $ver
    $info = @()

    $install_info_path = "$(versiondir $app $ver $global)\install.json"
    $updated = (Get-Item (appdir $app $global)).LastWriteTime | Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $install_info = $null
    if(Test-Path $install_info_path) {
        $install_info = parse_json $install_info_path
        $updated = (Get-Item $install_info_path).LastWriteTime | Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }

    $item.Source = if ($install_info.bucket) {
        $install_info.bucket
    } elseif ($install_info.url) {
        if ($install_info.url -eq (usermanifest $app)) { $info += "Auto-generated" }
        $install_info.url
    }
    $item.Updated = $updated

    if($global) { $info += "Global install" }
    if (!$install_info) { $info += "Install failed" }
    if ($install_info.hold) { $info += "Held package" }
    if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
        $info += $install_info.architecture
    }
    $item.Info = $info -join ', '

    $list += $item
}

$list.ForEach({[PSCustomObject]$_})
exit 0
