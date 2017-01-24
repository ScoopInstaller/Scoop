# Usage: scoop install <app> [options]
# Summary: Install apps
# Help: e.g. The usual way to install an app (uses your local 'buckets'):
#      scoop install git
#
# To install an app from a manifest at a URL:
#      scoop install https://raw.github.com/lukesampson/scoop/master/bucket/runat.json
#
# To install an app from a manifest on your computer
#      scoop install \path\to\app.json
#
# When installing from your computer, you can leave the .json extension off if you like.
#
# Options:
#   -a, --arch <32bit|64bit>  use the specified architecture, if the app supports it
#   -i, --independent         don't install dependencies automatically
#   -g, --global              install the app globally

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\shortcuts.ps1"
. "$psscriptroot\..\lib\psmodules.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"

reset_aliases

function ensure_not_installed($app, $global) {
    if(installed $app $global) {
        $global_flag = $null;
        if($global){ $global_flag = ' --global' }

        $version = @(versions $app $global)[-1]
        if(!(install_info $app $version $global)) {
            abort "it looks like a previous installation of $app failed.`nrun 'scoop uninstall $app$global_flag' before retrying the install."
        }
        abort "$app ($version) is already installed.`nuse 'scoop update $app$global_flag' to install a new version."
    }
}

$opt, $apps, $err = getopt $args 'gia:' 'global', 'independent', 'arch='
if($err) { "scoop install: $err"; exit 1 }

$global = $opt.g -or $opt.global
$independent = $opt.i -or $opt.independent
$architecture = ensure_architecture ($opt.a + $opt.arch)

if(!$apps) { 'ERROR: <app> missing'; my_usage; exit 1 }

if($global -and !(is_admin)) {
    'ERROR: you need admin rights to install global apps'; exit 1
}

if($apps.length -eq 1) {
    ensure_not_installed $apps $global
}

# remember which were explictly requested so that we can
# differentiate after dependencies are added
$explicit_apps = $apps 

if(!$independent) {
    $apps = install_order $apps $architecture # adds dependencies
}
ensure_none_failed $apps $global

$apps, $skip = prune_installed $apps $global

$skip | ? { $explicit_apps -contains $_} | % { warn "$_ is already installed, skipping" }

$apps | % { install_app $_ $architecture $global }

exit 0
