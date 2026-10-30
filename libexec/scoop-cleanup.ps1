# Usage: scoop cleanup <app> [options]
# Summary: Cleanup apps by removing old versions
# Help: 'scoop cleanup' cleans Scoop apps by removing old versions.
# 'scoop cleanup <app>' cleans up the old versions of that app if said versions exist.
#
# You can use '*' in place of <app> or `-a`/`--all` switch to cleanup all apps.
#
# Options:
#   -a, --all          Cleanup all apps (alternative to '*')
#   -g, --global       Cleanup a globally installed app
#   -k, --cache        Remove outdated download cache

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Select-CurrentVersion' (indirectly)
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\install.ps1" # persist related

$opt, $apps, $err = getopt $args 'agk' 'all', 'global', 'cache'
if ($err) { error "scoop cleanup: $err"; exit 1 }
$global = $opt.g -or $opt.global
$cache = $opt.k -or $opt.cache
$all = $opt.a -or $opt.all
$failed = @{}

if (!$apps -and !$all) { error '<app> missing'; my_usage; exit 1 }

if ($global -and !(is_admin)) {
    error 'you need admin rights to cleanup global apps'; exit 1
}

function cleanup($app, $global, $verbose, $cache) {
    $current_version = Select-CurrentVersion -AppName $app -Global:$global
    if ($cache) {
        Remove-Item "$cachedir\$app#*" -Exclude "$app#$current_version#*"
    }
    $appDir = appdir $app $global
    $versions = Get-ChildItem $appDir -Name
    $versions = $versions | Where-Object { $current_version -ne $_ -and $_ -ne 'current' }
    if (!$versions) {
        if ($verbose) { success "$app is already clean" }
        return
    }

    Write-Host -f yellow "Removing $app`: " -NoNewline
    try {
        $versions | ForEach-Object {
            $version = $_
            Write-Host "$version... " -NoNewline
            $dir = versiondir $app $version $global
            # unlink all potential old link before doing recursive Remove-Item
            unlink_persist_data (installed_manifest $app $version $global) $dir
            Remove-Item $dir -ErrorAction Stop -Recurse -Force
        }
        $leftVersions = Get-ChildItem $appDir
        if ($leftVersions.Length -eq 1 -and $leftVersions.Name -eq 'current' -and $leftVersions.LinkType) {
            attrib $leftVersions.FullName -R /L
            Remove-Item $leftVersions.FullName -ErrorAction Stop -Force
            $leftVersions = $null
        }
        if (!$leftVersions) {
            Remove-Item $appDir -ErrorAction Stop -Force
        }
    } catch {
        Write-Host 'Error.' -ForegroundColor DarkRed
        error "Couldn't remove an old version of '$app'; it may be in use."
        $failed[$app] = 'could not remove an old version'
        return
    }
    Write-Host 'Done.' -ForegroundColor Green
}

if ($apps -or $all) {
    if ($apps -eq '*' -or $all) {
        $verbose = $false
        $apps = applist (installed_apps $false) $false
        if ($global) {
            $apps += applist (installed_apps $true) $true
        }
    } else {
        $verbose = $true
        $install_status = Confirm-InstallationStatus $apps -Global:$global
        $apps = $install_status.installed
        $install_status.failed.Keys | Where-Object { $install_status.failed[$_] -eq 'not installed in the requested scope' } | ForEach-Object { $failed[$_] = $install_status.failed[$_] }
    }

    # $apps is now a list of ($app, $global) tuples
    $apps | ForEach-Object { cleanup @_ $verbose $cache }

    if ($cache) {
        Remove-Item "$cachedir\*.download" -ErrorAction Ignore
    }

    if (!$verbose) {
        success 'Everything is shiny now!'
    }
}

$failed_count = show_failed_apps $failed 'cleanup'

exit [int]($failed_count -gt 0)
