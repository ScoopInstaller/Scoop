# Note: This file is for overwriting global variables and functions to make
#       them unix compatible. It has to be imported after everything else!

function is_unix() { $PSVersionTable.Platform -eq 'Unix' }
function is_mac() { $PSVersionTable.OS.ToLower().StartsWith('darwin') }
function is_linux() { $PSVersionTable.OS.ToLower().StartsWith('linux') }

if(!(is_unix)) {
    return # get the hell outta here
}

# core.ps1
$scoopdir = $env:SCOOP, (get_config 'rootPath'), (Join-Path $env:HOME "scoop") | Select-Object -first 1
$globaldir = $env:SCOOP_GLOBAL, (get_config 'globalPath'), "/usr/local/scoop" | Select-Object -first 1
$cachedir = $env:SCOOP_CACHE, (get_config 'cachePath'), (Join-Path $scoopdir "cache") | Select-Object -first 1

# core.ps1
function ensure($dir) {
    mkdir -p $dir > $null
    return resolve-path $dir
}

# install.ps1
function compute_hash($file, $algname) {
    if(is_mac) {
        switch ($algname)
        {
            "md5" { $result = (md5 -q $file) }
            "sha1" { $result = (shasum -ba 1 $file) }
            "sha256" { $result = (shasum -ba 256 $file) }
            "sha512" { $result = (shasum -ba 512 $file) }
            default { $result = (shasum -ba 256 $file) }
        }
    } else {
        switch ($algname)
        {
            "md5" { $result = (md5sum -b $file) }
            "sha1" { $result = (sha1sum -b $file) }
            "sha256" { $result = (sha256sum -b $file) }
            "sha512" { $result = (sha512sum -b $file) }
            default { $result = (sha256sum -b $file) }
        }
    }
    return $result.split(' ') | Select-Object -first 1
}
