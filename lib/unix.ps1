# Note: This file is for overwriting global variables and functions to make
#       them unix compatible. It has to be imported after everything else!

function is_unix() { $PSVersionTable.Platform -eq 'Unix' }
function is_mac() { $PSVersionTable.OS.ToLower().StartsWith('darwin') }
function is_linux() { $PSVersionTable.OS.ToLower().StartsWith('linux') }

if(!(is_unix)) {
    return # get the hell outta here
}

# core.ps1
$scoopdir = $env:SCOOP, (get_config ROOT_PATH), (Join-Path $env:HOME 'scoop') | Select-Object -First 1
$globaldir = $env:SCOOP_GLOBAL, (get_config 'GLOBAL_PATH'), '/usr/local/scoop' | Select-Object -First 1
$cachedir = $env:SCOOP_CACHE, (get_config 'CACHE_PATH'), (Join-Path $scoopdir 'cache') | Select-Object -First 1

# core.ps1
function ensure($dir) {
    mkdir -p $dir > $null
    return Convert-Path $dir
}
