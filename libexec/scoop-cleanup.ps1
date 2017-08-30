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

if($apps) {
    if ($apps -eq '*') {
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    }
    else {
        $apps = ensure_all_installed $apps $global
        $apps = applist $apps $global
    }

    # $apps is now a list of ($app, $global) tuples
    $apps | ForEach-Object { cleanup @_ }
}

exit 0
