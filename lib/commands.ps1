function command_files {
    gci (resolve 'cmd') | where { $_.name.endswith('.ps1') }
}

function commands {
    command_files | % { command_name $_ }
}

function command_name($filename) { $filename.name -replace '\.ps1$', '' }

function exec($cmd, $arguments) {
    & (resolve "cmd\$cmd.ps1") @arguments
}