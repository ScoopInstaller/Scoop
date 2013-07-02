function command_files {
	gci (relpath '..\libexec') | where { $_.name.endswith('.ps1') }
}

function commands {
	command_files | % { command_name $_ }
}

function command_name($filename) { $filename.name -replace '\.ps1$', '' }

function exec($cmd, $arguments) {
	& (relpath "..\libexec\$cmd.ps1") @arguments
}