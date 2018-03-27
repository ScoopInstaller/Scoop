# Usage: scoop cleanup <app> [options]
# Summary: Cleanup apps by removing old versions
# Help: 'scoop cleanup' cleans Scoop apps by removing old versions.
# 'scoop cleanup <app>' cleans up the old versions of that app if said versions exist.
#
# You can use '*' in place of <app> to cleanup all apps.
#
# Options:
#   --global, -g       Cleanup a globally installed app
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'g' 'global'
if ($err) { "scoop cleanup: $err"; exit 1 }
$global = $opt.g -or $opt.global

if(!$apps) { 'ERROR: <app> missing'; my_usage; exit 1 }

if($global -and !(is_admin)) {
    'ERROR: you need admin rights to cleanup global apps'; exit 1
}

function cleanup($app, $global, $verbose) {
    $current_version  = current_version $app $global
    $versions = versions $app $global | Where-Object { $_ -ne $current_version -and $_ -ne 'current' }
    if(!$versions) {
        if($verbose) { success "$app is already clean" }
        return
    }

    write-host -f yellow "Removing $app`:" -nonewline
    $versions | ForEach-Object {
        $version = $_
        write-host " $version" -nonewline
        $dir = versiondir $app $version $global
        Get-ChildItem $dir | ForEach-Object {
            $file = $_
            if($null -ne $file.LinkType) {
                fsutil.exe reparsepoint delete $file.FullName | out-null
            }
        }
        Remove-Item $dir -Recurse -Force
    }
    write-host ''
}

if($apps) {
    $verbose = $true
    if ($apps -eq '*') {
        $verbose = $false
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    }
    else {
        $apps = ensure_all_installed $apps $global
    }

    # $apps is now a list of ($app, $global) tuples
    $apps | ForEach-Object { cleanup @_ $verbose }

    if(!$verbose) {
        success 'Everything is shiny now!'
    }
}

exit 0
