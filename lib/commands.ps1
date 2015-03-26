function command_files {
	(gci (relpath '..\libexec')) `
        + (gci "$env:scoop\shims") `
        | where { $_.name -match 'scoop-.*?\.ps1$' }
}

function commands {
	command_files | % { command_name $_ }
}

function command_name($filename) {
	$filename.name | sls 'scoop-(.*?)\.ps1$' | % { $_.matches[0].groups[1].value }
}

function command_path($cmd) {
    $cmd_path = relpath "..\libexec\scoop-$cmd.ps1"

    # built in commands
    if (!(Test-Path $cmd_path)) {
        # get path from shim
        $shim_path = "$env:scoop\shims\scoop-$cmd.ps1"
        $line = ((gc $shim_path) | where { $_.startswith('$path') })
        iex -command "$line"
        $cmd_path = $path
    } 

    $cmd_path
}

function exec($cmd, $arguments) {
    $cmd_path = command_path $cmd

    & $cmd_path @arguments
}
