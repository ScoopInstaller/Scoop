<#
.SYNOPSIS
    Format manifest.
.PARAMETER App
    Manifest to format.

    Wildcards are supported.
.PARAMETER Dir
    Where to search for manifest(s).
.EXAMPLE
    PS BUCKETROOT> .\bin\formatjson.ps1
    Format all manifests inside bucket directory.
.EXAMPLE
    PS BUCKETROOT> .\bin\formatjson.ps1 7zip
    Format manifest '7zip' inside bucket directory.
#>
param(
    [String] $App = '*',
    [Parameter(Mandatory = $true)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [String] $Dir
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\json.ps1"

$Dir = Convert-Path $Dir

Get-ChildItem $Dir -Filter "$App.json" -Recurse | ForEach-Object {
    # Path of file
    $file = [string] $_.'FullName'

    # Parse JSON
    $json = [PSCustomObject](parse_json -path $file)

    # Sort JSON root properties
    $json = [PSCustomObject](Sort-ScoopManifestRootProperties -JsonAsObject $json)

    # Beautify
    $json = [string](ConvertToPrettyJson -data $json)

    # Convert to 4 spaces
    $json = [string]($json -replace "`t", '    ')

    # Overwrite file content
    [System.IO.File]::WriteAllLines($file, $json)
}
