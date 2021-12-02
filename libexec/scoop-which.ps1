# Usage: scoop which <command>
# Summary: Locate a shim/executable (similar to 'which' on Linux)
# Help: Locate the path to a shim/executable that was installed with Scoop (similar to 'which' on Linux)
param($command)
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

if(!$command) { 'ERROR: <command> missing'; my_usage; exit 1 }

try {
    $gcm = Get-Command "$command" -ea stop
} catch {
    abort "'$command' not found" 3
}

$path = "$($gcm.path)"
$usershims = "$(resolve-path $(shimdir $false))"
$globalshims = fullpath (shimdir $true) # don't resolve: may not exist

if($path -like "$usershims*" -or $path -like "$globalshims*") {
    $exepath = if ($path.endswith(".exe") -or $path.endswith(".shim")) {
        (Get-Content ($path -replace '\.exe$', '.shim') | Select-Object -First 1).replace('path = ', '')
    } else {
        ((Select-String -Path $path -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
    }
    if (!$exepath) {
        $exepath = ((Select-String -Path $path -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
    }

    if(![system.io.path]::ispathrooted($exepath)) {
        # Expand relative path
        $exepath = resolve-path (join-path (split-path $path) $exepath)
    }

    friendly_path $exepath
} elseif($gcm.commandtype -eq 'Application') {
    $gcm.Source
} elseif($gcm.commandtype -eq 'Alias') {
    scoop which $gcm.resolvedcommandname
} else {
    [console]::error.writeline("Not a scoop shim.")
    $path
    exit 2
}

exit 0
