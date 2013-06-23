# Usage: scoop list
# Summary: List available apps
# Help: Lists all apps available to install.
# (showing installed apps tbd)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

echo "Installed apps:
"
gci ( "$scoopdir\apps") | where { $_.psiscontainer -and $_.name -ne 'scoop' } | % { $_.name }

""