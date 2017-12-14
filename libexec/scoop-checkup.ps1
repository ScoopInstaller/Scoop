# Usage: scoop checkup
# Summary: Check for potential problems
# Help: Performs a series of diagnostic tests to try to identify things that may
# cause problems with Scoop.

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\diagnostic.ps1"

$issues = 0

$issues += !(check_windows_defender $false)
$issues += !(check_windows_defender $true)

if($issues) {
    warn "`nFound $issues potential $(pluralize $issues problem problems)."
} else {
    success "No problems identified!"
}

exit 0
