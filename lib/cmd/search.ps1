# Usage: scoop search [query]
# Summary: Search available apps
# Help: Searches for apps that are available to install.
# 
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
param($query)
. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

if($query) { warn "sorry, queries aren't implemented yet" }

echo "Available apps:
"
gci (resolve '..\..\bucket') |
    where { $_.name.endswith('.json') } |
    % { $_ -replace '.json$', '' }

""

exit 0