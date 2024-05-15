# Usage: scoop install <app> [options]
# Summary: Install apps
# Help: e.g. The usual way to install an app (uses your local 'buckets'):
#      scoop install git
#
# To install a different version of the app
# (note that this will auto-generate the manifest using current version):
#      scoop install gh@2.7.0
#
# To install an app from a manifest at a URL:
#      scoop install https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/runat.json
#
# To install a different version of the app from a URL:
#       scoop install https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/neovim.json@0.9.0
#
# To install an app from a manifest on your computer
#      scoop install \path\to\app.json
#
# To install an app from a manifest on your computer
#      scoop install \path\to\app.json@version
#
# Options:
#   -g, --global                    Install the app globally
#   -i, --independent               Don't install dependencies automatically
#   -k, --no-cache                  Don't use the download cache
#   -s, --skip-hash-check           Skip hash validation (use with caution!)
#   -u, --no-update-scoop           Don't update Scoop before installing if it's outdated
#   -a, --arch <32bit|64bit|arm64>  Use the specified architecture, if the app supports it

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'autoupdate.ps1' 'manifest.ps1' (indirectly)
. "$PSScriptRoot\..\lib\autoupdate.ps1" # 'generate_user_manifest' (indirectly)
. "$PSScriptRoot\..\lib\manifest.ps1" # 'generate_user_manifest' 'Get-Manifest' 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\system.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\download.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\shortcuts.ps1"
. "$PSScriptRoot\..\lib\psmodules.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\depends.ps1"
if (get_config USE_SQLITE_CACHE) {
    . "$PSScriptRoot\..\lib\database.ps1"
}

$opt, $apps, $err = getopt $args 'giksua:' 'global', 'independent', 'no-cache', 'skip-hash-check', 'no-update-scoop', 'arch='
if ($err) { "scoop install: $err"; exit 1 }

$global = $opt.g -or $opt.global
$check_hash = !($opt.s -or $opt.'skip-hash-check')
$independent = $opt.i -or $opt.independent
$use_cache = !($opt.k -or $opt.'no-cache')
$architecture = Get-DefaultArchitecture
try {
    $architecture = Format-ArchitectureString ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

if (!$apps) { error '<app> missing'; my_usage; exit 1 }

if ($global -and !(is_admin)) {
    abort 'ERROR: you need admin rights to install global apps'
}

if (is_scoop_outdated) {
    if ($opt.u -or $opt.'no-update-scoop') {
        warn "Scoop is out of date."
    } else {
        & "$PSScriptRoot\scoop-update.ps1"
    }
}

ensure_none_failed $apps

if ($apps.length -eq 1) {
    $app, $null, $version = parse_app $apps
    if ($app.EndsWith('.json')) {
        $app = [System.IO.Path]::GetFileNameWithoutExtension($app)
    }
    $curVersion = Select-CurrentVersion -AppName $app -Global:$global
    if ($null -eq $version -and $curVersion) {
        warn "'$app' ($curVersion) is already installed.`nUse 'scoop update $app$(if ($global) { ' --global' })' to install a new version."
        exit 0
    }
}

# get any specific versions that we need to handle first
$specific_versions = $apps | Where-Object {
    $null, $null, $version = parse_app $_
    return $null -ne $version
}

# compare object does not like nulls
if ($specific_versions.length -gt 0) {
    $difference = Compare-Object -ReferenceObject $apps -DifferenceObject $specific_versions -PassThru
} else {
    $difference = $apps
}

$specific_versions_paths = $specific_versions | ForEach-Object {
    $app, $bucket, $version = parse_app $_
    if (installed_manifest $app $version) {
        warn "'$app' ($version) is already installed.`nUse 'scoop update $app$(if ($global) { " --global" })' to install a new version."
        continue
    }

    generate_user_manifest $app $bucket $version
}
$apps = @(($specific_versions_paths + $difference) | Where-Object { $_ } | Sort-Object -Unique)

# remember which were explictly requested so that we can
# differentiate after dependencies are added
$explicit_apps = $apps

if (!$independent) {
    $apps = $apps | Get-Dependency -Architecture $architecture | Select-Object -Unique # adds dependencies
}
ensure_none_failed $apps

$apps, $skip = prune_installed $apps $global

$skip | Where-Object { $explicit_apps -contains $_ } | ForEach-Object {
    $app, $null, $null = parse_app $_
    $version = Select-CurrentVersion -AppName $app -Global:$global
    warn "'$app' ($version) is already installed. Skipping."
}

$suggested = @{ };
if ((Test-Aria2Enabled) -and (get_config 'aria2-warning-enabled' $true)) {
    warn "Scoop uses 'aria2c' for multi-connection downloads."
    warn "Should it cause issues, run 'scoop config aria2-enabled false' to disable it."
    warn "To disable this warning, run 'scoop config aria2-warning-enabled false'."
}
$apps | ForEach-Object { install_app $_ $architecture $global $suggested $use_cache $check_hash }

show_suggestions $suggested

exit 0
