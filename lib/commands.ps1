function command_files {
	gci (relpath '..\libexec') | where { $_.name -match 'scoop-.*?\.ps1$' }
}

function commands {
	command_files | % { command_name $_ }
}

function command_name($filename) {
    $filename.name | sls 'scoop-(.*?)\.ps1$' | % { $_.matches[0].groups[1].value }
}

function exec($cmd, $arguments) {
	& (relpath "..\libexec\scoop-$cmd.ps1") @arguments
}