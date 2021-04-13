# Usage: scoop rife <app> [options]
# Summary: Reveal app in file explorer
#
# Options:
#   -h, --help      Show help for this command.

param($app)

'help', 'Versions' | ForEach-Object {
    . (Join-Path $PSScriptRoot "..\lib\$_.ps1")
}

if (!$app) { Stop-ScoopExecution -Message 'Parameter <app> missing' -Usage (my_usage) }

if ($app) {
    $global = installed $app $true
    $status = app_status $app $global
}

if ($status.installed) {
    $dir = versiondir $app $_ $global
    $versions = Get-InstalledVersion -AppName $app -Global:$global
    try {
        if ($versions.getType().Name -eq 'String') {
            $dir += $versions
        } else {
            $dir += $versions[-1]
        }
    } catch {
        $dir += 'current'
    }
    Start-Process $dir
} else {
    Write-UserMessage -Message "'$app' isn't installed." -Err
}

exit 0
