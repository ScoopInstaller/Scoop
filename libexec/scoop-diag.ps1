# Usage: scoop diag
# Summary: Returns information about the Scoop environment that can be posted on a GitHub issue

. "$PSScriptRoot\..\lib\diagnostic.ps1"

Show-Diag -Markdown -Color

exit 0
