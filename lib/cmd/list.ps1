# Usage: scoop list
# Summary: List available apps
# Help: Lists all apps available to install.
# (showing installed apps tbd)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

echo "Available apps:
"
gci (resolve '..\..\bucket') |
	where { $_.name.endswith('.json') } |
	% { $_ -replace '.json$', '' }

""