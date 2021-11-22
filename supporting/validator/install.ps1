# https://github.com/edymtt/nugetstandalone
$destinationFolder = "$PSScriptRoot\packages"
if ((Test-Path -Path $destinationFolder)) {
    Remove-Item -Path $destinationFolder -Recurse | Out-Null
}

New-Item $destinationFolder -Type Directory | Out-Null
nuget install packages.config -o $destinationFolder -ExcludeVersion
