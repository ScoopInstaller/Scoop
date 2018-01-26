# Usage: scoop list [query]
# Summary: List installed apps
# Help: Lists all installed apps, or the apps matching the supplied query.
param($query)

."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\versions.ps1"
."$psscriptroot\..\lib\manifest.ps1"
."$psscriptroot\..\lib\buckets.ps1"

reset_aliases
$def_arch = default_architecture

$local = installed_apps $false | ForEach-Object { @{ Name = $_ } }
$global = installed_apps $true | ForEach-Object { @{ Name = $_; global = $true } }

$apps = @( $local) + @( $global)

if ($apps) {
  Write-Host "Installed apps$(if($query) { `" matching '$query'`"}): `n"
  $apps | sort { $_.Name } | Where-Object { !$query -or ($_.Name -match $query) } | ForEach-Object {
    $app = $_.Name
    $global = $_.global
    $ver = current_version $app $global

    $install_info = install_info $app $ver $global
    Write-Host "  $app " -NoNewline
    Write-Host -f DarkCyan $ver -NoNewline
    if ($global) {
      Write-Host -f DarkRed ' *global*' -NoNewline
    }
    if ($install_info.bucket) {
      Write-Host -f Yellow " [$($install_info.bucket)]" -NoNewline
    } elseif ($install_info.url) {
      Write-Host -f Yellow " [$($install_info.url)]" -NoNewline
    }
    if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
      Write-Host -f DarkRed " {$($install_info.architecture)}" -NoNewline
    }
    Write-Host ''
  }
  Write-Host ''
  exit 0
} else {
  Write-Host "There aren't any apps installed."
  exit 1
}
