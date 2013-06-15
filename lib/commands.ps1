function commands {
    gci (resolve 'cmd') |
        where { $_.name.endswith('.ps1') } |
        % { ($_.name -replace '\.ps1$', '') }
}

function exec($cmd) {
    & (resolve "cmd\$cmd.ps1")
}