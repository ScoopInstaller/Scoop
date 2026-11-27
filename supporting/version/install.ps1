param([Switch]$Force)

$nuget = Get-Command nuget -ErrorAction SilentlyContinue
if (-not $nuget) {
    Write-Warning "nuget is required to build the prebuilt assemblies. Install it with 'scoop install nuget' and run this again."
    exit 1
}
# A nuget older than 6 does not understand 'install packages.config -ExcludeVersion'.
$version = (& $nuget.Source help 2>$null | Select-Object -First 1) -replace '.*?(\d+\.\d+\.\d+).*', '$1'
if ($version -notmatch '^\d+\.\d+\.\d+$' -or [version]$version -lt [version]'6.0') {
    Write-Warning "nuget $version is too old, 6.0 or newer is required. Update it with 'scoop update nuget'."
    exit 1
}
$destinationFolder = "$PSScriptRoot\packages"
# To move to another version, change it in packages.config and run this with -Force.
$arguments = @('install', "$PSScriptRoot\packages.config", '-OutputDirectory', $destinationFolder, '-ExcludeVersion')
if ($Force) { $arguments += '-Force' }
& $nuget.Source @arguments
if ($LASTEXITCODE -ne 0) {
    throw "nuget failed with exit code $LASTEXITCODE"
}
