# Usage: scoop which <command>
# Summary: Locate a shim/executable (similar to 'which' on Linux)
# Help: Locate the path to a shim/executable that was installed with Scoop (similar to 'which' on Linux)
param($command)

if (!$command) {
    error '<command> missing'
    my_usage
    exit 1
}

$path = Get-CommandPath $command

if ($null -eq $path) {
    warn "'$command' not found, not a scoop shim, or a broken shim."
    exit 2
} else {
    friendly_path $path
    exit 0
}
