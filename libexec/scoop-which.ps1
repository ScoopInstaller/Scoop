# Usage: scoop which <command>
# Summary: Locate a shim/executable (similar to 'which' on Linux)
# Help: Locate the path to a shim/executable that was installed with Scoop (similar to 'which' on Linux)
param($command)

if (!$command) {
    'ERROR: <command> missing'
    my_usage
    exit 1
}

try {
    $gcm = Get-Command "$command" -ErrorAction Stop
} catch {
    abort "'$command' not found" 3
}

$path = $gcm.Path
$usershims = Convert-Path (shimdir $false)
$globalshims = fullpath (shimdir $true) # don't resolve: may not exist

if ($path -like "$usershims*" -or $path -like "$globalshims*") {
    $exepath = if ($path.EndsWith('.exe') -or $path.EndsWith('.shim')) {
        (Get-Content ($path -replace '\.exe$', '.shim') | Select-Object -First 1).Replace('path = ', '').Replace('"', '')
    } else {
        ((Select-String -Path $path -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
    }
    if (!$exepath) {
        $exepath = ((Select-String -Path $path -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
    }

    if (![System.IO.Path]::IsPathRooted($exepath)) {
        # Expand relative path
        $exepath = Convert-Path $exepath
    }

    friendly_path $exepath
} elseif ($gcm.CommandType -eq 'Application') {
    $gcm.Source
} elseif ($gcm.CommandType -eq 'Alias') {
    scoop which $gcm.ResolvedCommandName
} else {
    Write-Host 'Not a scoop shim.'
    $path
    exit 2
}

exit 0
