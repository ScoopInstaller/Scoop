. .\lib\init.ps1

if(test-path $scoopdir) {
    try {
        rm -r $scoopdir -ea stop
    } catch {
        abort "couldn't remove $(friendly_path $scoopdir): it may be in use"
    }
}

$bindir_regex = [regex]::escape((full_path $bindir))
if((env 'path') -match $bindir_regex) { # future sessions
    echo "removing $(friendly_path $bindir) from your path"
    env 'path' ((env 'path') -replace $bindir_regex, '')
}

success "scoop has been uninstalled"