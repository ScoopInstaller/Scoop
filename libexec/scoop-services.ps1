# Usage: scoop services install|uninstall|start|stop|restart|status|update|list <app> [options]
# Summary: Manage app services
# Help: scoop services install|uninstall <app>    installs|uninstalls a service.
# scoop services start|stop|restart <app>   start|stop|restart the service.
# scoop services status <app>               show status of the service.
# scoop services update <app>               updates the WinSW executable (stops and starts the service)
# scoop services list                       lists all available service (only from installed apps)
#
# Options:
#   --all, -a                               start|stop|restart all available services
param(
    [String]$cmd,
    [String]$name,
    [Switch]$all = $false,
    [Switch]$global = $false
)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\git.ps1"

reset_aliases

function warn_no_app($cmd, $app) {
    if(!$app) {
        write-host "Usage: scoop services $cmd <app>"
        exit 1
    }
}

function warn_no_admin($cmd, $app) {
    if(!(is_admin)) {
        warn "Scoop services requires admin privileges. Run command with 'sudo'"
        write-host "Usage: sudo scoop services $cmd $app"
        exit 1
    }
}

function warn_not_configured($app) {
    if(!(is_configured $app)) {
        warn "Service '$app' is not properly configured!"
        write-host "Usage: scoop services install $app"
        exit 1
    }
}

function warn_not_installed($app) {
    if(!(is_installed $app)) {
        warn "Service '$app' is not properly installed!"
        write-host "Usage: scoop services install $app"
        exit 1
    }
}

function service_cmd($cmd, $app, $sudo) {
    $service_dir = servicedir $app $global
    if($sudo -eq $null) { $sudo = $true }

    if($sudo) {
        cmd /c "sudo $service_dir\$app-service.exe" $cmd
        if($LASTEXITCODE -eq 1) {
            warn_no_admin $cmd $app
        }
    } else {
        cmd /c "$service_dir\$app-service.exe" $cmd
    }
    Start-Sleep 1
}

function stop_service($app) {
    warn_no_app 'stop' $app
    warn_not_configured $app
    warn_not_installed $app

    if(is_running $app) {
        write-host "Stopping $app service ..."
        service_cmd 'stop' $app
    } else {
        write-host "$app service is not running ..."
    }
}

function start_service($app) {
    warn_no_app 'start' $app
    warn_not_configured $app
    warn_not_installed $app

    if(!(is_running $app)) {
        write-host "Starting $app service ..."
        service_cmd 'start' $app
    } else {
        write-host "$app service is already running ..."
    }
}

function uninstall_service($app, $cmd) {
    warn_no_app 'uninstall' $app
    warn_not_configured $app

    if(is_running $app) {
        write-host "Stopping $app service ..."
        service_cmd 'stop' $app
    }
    if(is_installed $app) {
        write-host "Uninstalling $app service ..."
        service_cmd 'uninstall' $app
    } else {
        write-host "$app service is not installed ..."
    }
}

function update_service($app) {
    warn_no_app 'update' $app
    warn_not_configured $app

    $was_running = is_running $app
    if($was_running) {
        write-host "Stopping $app service ..."
        service_cmd 'stop' $app
    }
    $winsw_version = current_version "winsw"
    $service_dir = ensure (servicedir $app $global)
    write-host "Updating '$service_dir\$app-service.exe' to WinSW version $winsw_version"
    Copy-Item "$(versiondir 'winsw' 'current')\winsw.exe" "$service_dir\$app-service.exe" | out-null

    if($was_running) {
        write-host "Starting $app service ..."
        service_cmd 'start' $app
    } else {
        write-host "Usage: scoop services start $app"
    }
}

function status_service($app) {
    warn_no_app 'update' $app
    service_cmd 'status' $app $false
}

function restart_service($app) {
    warn_no_app 'restart' $app
    warn_not_configured $app
    warn_not_installed $app

    write-host "Restarting $app service ..."
    if(is_running $app) {
        service_cmd 'stop' $app
    }
    service_cmd 'start' $app
}

function install_service($app) {
    warn_no_app 'install' $app

    $version = current_version $app $global
    $manifest = installed_manifest $app $version $global
    $install = install_info $app $version $global
    $service = $manifest.service

    $versiondir = versiondir $app $version $global
    $dir = current_dir $versiondir
    $bucket_dir = bucketdir $install.bucket
    $persist_dir = ensure (persistdir $app $global)
    $service_dir = ensure (servicedir $app $global)

    if(!(is_configured $app)) {
        Copy-Item "$(versiondir 'winsw' 'current')\winsw.exe" "$service_dir\$app-service.exe"

        if(!(test-path "$bucket_dir\services\$service.xml")) {
            error "Could not find '$bucket_dir\services\$service.xml'"
            return
        } elseif(!(test-path "$service_dir\$app-service.xml")) {
            $service_xml = [System.IO.File]::ReadAllText("$bucket_dir\services\$service.xml")
            $service_xml = substitute $service_xml @{
                '$name' = $service
                '$app' = $app
                '$dir' = $dir
                '$version' = $version
                '$service_dir' = $service_dir
                '$persist_dir' = $persist_dir
            }
            [System.IO.File]::WriteAllLines("$service_dir\$app-service.xml", $service_xml)
        } else {
            error "Something went wrong while creating '$app-service.xml'"
            return
        }
    }

    if(!(is_installed $app)) {
        write-host "Installing $app service ..."
        service_cmd 'install' $app
    } else {
        write-host "$app service is already installed ..."
    }
    write-host "Usage: scoop services start $app"
}

function list_services {

    write-host "[" -nonewline
    write-host -f yellow "C" -nonewline
    write-host "]onfigured"
    write-host " | [" -nonewline
    write-host -f blue "I" -nonewline
    write-host "]nstalled"
    write-host " |  | [" -nonewline
    write-host -f green "S" -nonewline
    write-host "]atus"
    write-host " |  |  |"

    $true, $false | % { # local and global apps
        $global = $_
        $dir = appsdir $global
        if(!(test-path $dir)) { return }

        gci $dir | ? name -ne 'scoop' | % {
            $app = $_.name
            $version = current_version $app $global
            if(!$version) { return }

            $manifest = installed_manifest $app $version $global
            if(!$manifest.service) { return }

            $service = $manifest.service
            $configured = is_configured $app
            if($configured) {
                $status = status $app
            } else {
                $status = 'nonexistent'
            }

            write-host "[" -nonewline
            if($configured) { write-host -f green -nonewline "+" }
            else { write-host -f red -nonewline "-" }
            write-host "]" -nonewline

            write-host "[" -nonewline
            if($status -ne 'nonexistent') { write-host -f green -nonewline "+" }
            else { write-host -f red -nonewline "-" }
            write-host "]" -nonewline

            write-host "[" -nonewline
            if($status -eq 'started') { write-host -f green -nonewline "+" }
            elseif($status -eq 'stopped') { write-host -f yellow -nonewline "S" }
            else { write-host -f red -nonewline "-" }
            write-host "] " -nonewline
            write-host "$app ($service)"
        }
    }
}

function status($app) {
    $service_dir = ensure (servicedir $app $global)
    return (Invoke-Expression "$service_dir\$app-service.exe status") | Select-Object -index 2 | % { $_.ToLower() }
}

function is_configured($app) {
    $service_dir = ensure (servicedir $app $global)
    return ((test-path "$service_dir\$app-service.exe") -and (test-path "$service_dir\$app-service.xml"))
}

function is_running($app) {
    $status = status $app
    return ($status -eq 'started' -and $status -ne 'nonexistent')
}

function is_installed($app) {
    $status = status $app
    return ($status -ne 'nonexistent')
}

function get_app_services($app) {
    $version = current_version $app $global
    $manifest = installed_manifest $app $version $global
    $install = install_info $app $version $global

    $bucket = bucketdir $install.bucket

    if([string]::isnullorempty($manifest.services)) {
        throw "Could not find services in manifest for '$app'."
    }

    return $manifest.services, $bucket
}

if(!(installed 'sudo') -or !(installed 'winsw')) {
    warn "Scoop services requires sudo and WinSW to be installed!";
    "Usage: scoop install sudo winsw"; exit 1
}

switch($cmd) {
    "install" { install_service $name }
    "uninstall" { uninstall_service $name }
    "start" { start_service $name }
    "stop" { stop_service $name }
    "restart" { restart_service $name }
    "status" { status_service $name }
    "update" { update_service $name }
    "list" { list_services }
    "" { my_Usage; exit 1 }
    default { write-host "Scoop services command '$cmd' not supported"; my_Usage; exit 1 }
}
