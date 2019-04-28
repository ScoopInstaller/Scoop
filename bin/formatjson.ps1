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

$Dir = Resolve-Path $Dir

Get-ChildItem $Dir "$App.json" | ForEach-Object {
    if ($PSVersionTable.PSVersion.Major -gt 5) { $_ = $_.Name } # Fix for pwsh

    # beautify
    $json = parse_json "$Dir\$_" | ConvertToPrettyJson

    # convert to 4 spaces
    $json = $json -replace "`t", '    '
    [System.IO.File]::WriteAllLines("$Dir\$_", $json)
}
