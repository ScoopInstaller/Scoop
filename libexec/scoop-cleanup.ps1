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

function cleanup($app, $global) {
    $current_version  = current_version $app $global
    $installedappdir  = appdir $app $global
    write-host 'Cleaning up ' -nonewline
    write-host -f yellow $app
    foreach($versionDir in (Get-ChildItem $installedappdir))
    {
        if(($versionDir.Name -ne $current_version) -and ($versionDir.Name -ne 'current'))
        {
            foreach($file in (Get-ChildItem $installedappdir/$versionDir))
            {
                if($file.LinkType -ne $null)
                {
                    fsutil.exe reparsepoint delete $file.FullName
                }
            }
            write-host "- $versionDir"
            Remove-Item $versionDir.FullName -Recurse -Force
        }
    }
}

function ensure_all_installed($apps, $global) {
    $app = $apps | Where-Object { !(installed $_ $global) } | Select-Object -first 1 # just get the first one that's not installed
    if ($app) {
        if (installed $app (!$global)) {
            function wh($g) { if ($g) { "globally" } else { "for your account" } }
            write-host "'$app' isn't installed $(wh $global), but it is installed $(wh (!$global))." -f darkred
            "Try cleaning $(if($global) { 'without' } else { 'with' }) the --global (or -g) flag instead."
            exit 1
        }
        else {
            abort "'$app' isn't installed."
        }
    }
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
    return , @($apps | % { , @($_, $global) })
}
if($apps) {
    if ($apps -eq '*') {
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    }
    else {
        ensure_all_installed $apps $global
        $apps = applist $apps $global
    }

    # $apps is now a list of ($app, $global) tuples
    $apps | ForEach-Object { cleanup @_ }
}

exit 0
