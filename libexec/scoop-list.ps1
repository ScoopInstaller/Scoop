# Usage: scoop list [query] [options]
# Summary: List installed apps
# Help: Lists all installed apps, or the apps matching the supplied query.

# Options:
#   -i, --installed     List apps sorted by installed date
#   -u, --updated       List apps sorted by update time


'core', 'buckets', 'getopt', 'versions', 'manifest' | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

$opt, $query, $err = getopt $args 'iu' 'installed', 'updated'
# TODO: Stop-ScoopExecution
if ($err) { "scoop install: $err"; exit 1 }

$orderInstalled = $opt.i -or $opt.installed
$orderUpdated = $opt.u -or $opt.updated
# TODO: Stop-ScoopExecution
if ($orderUpdated -and $orderInstalled) { error '--installed and --updated parameters cannot be used simultaneously'; exit 1 }
$def_arch = default_architecture

$local = installed_apps $false | ForEach-Object { @{ name = $_; gci = (Get-ChildItem (appsdir $false) $_) } }
$global = installed_apps $true | ForEach-Object { @{ name = $_; gci = (Get-ChildItem (appsdir $true) $_); global = $true } }

$apps = @($local) + @($global)

if($apps) {
    $mes = if ($query) { " matching '$query'" }
    write-host "Installed apps${mes}: `n"

    if ($orderInstalled) {
        $sorted = $apps | Sort-Object { $_.gci.CreationTime }
    } elseif ($orderUpdated) {
        # TODO:
    } else {
        $sorted = $apps | Sort-Object { $_.name }
    }

    $sorted | Where-Object { !$query -or ($_.name -match $query) } | ForEach-Object {
        $app = $_.name
        $global = $_.global
        $ver = current_version $app $global

        $install_info = install_info $app $ver $global
        write-host "  $app " -NoNewline
        write-host -f DarkCyan $ver -NoNewline

        if($global) { write-host -f DarkGreen ' *global*' -NoNewline }

        if (!$install_info) { Write-Host ' *failed*' -ForegroundColor DarkRed -NoNewline }
        if ($install_info.hold) { Write-Host ' *hold*' -ForegroundColor DarkMagenta -NoNewline }

        if ($install_info.bucket) {
            write-host -f Yellow " [$($install_info.bucket)]" -NoNewline
        } elseif ($install_info.url) {
            write-host -f Yellow " [$($install_info.url)]" -NoNewline
        }

        if ($install_info.architecture -and $def_arch -ne $install_info.architecture) {
            write-host -f DarkRed " {$($install_info.architecture)}" -NoNewline
        }
        write-host ''
    }
    write-host ''
    exit 0
} else {
    write-host "There aren't any apps installed."
    exit 1
}
