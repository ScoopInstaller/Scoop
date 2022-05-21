# Usage: scoop which <command>
# Summary: Locate a shim/executable (similar to 'which' on Linux)
# Help: Locate the path to a shim/executable that was installed with Scoop (similar to 'which' on Linux)
param($command)

if (!$command) {
    'ERROR: <command> missing'
    my_usage
    exit 1
}

try {
    $gcm = Get-Command "$command" -ErrorAction Stop
} catch {
    abort "'$command' not found" 3
}

$path = Get-CommandPath $command
$path

if ($path -eq $null) {
    Write-Host 'Not a scoop shim.'
    exit 2
}

exit 0
