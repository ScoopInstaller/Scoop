<#
.SYNOPSIS
    Format manifest.
.PARAMETER App
    Manifest to format.
    Wildcard is supported.
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
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        }
        $true
    })]
    [Alias('Path')]
    # [String] $Dir = "$PSScriptRoot\..\bucket"
    # TODO: YAML Select correct dir
    [String] $Dir = "$PSScriptRoot\..\bucket\yamTEST"
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\json.ps1"

$Dir = Resolve-Path $Dir

Get-ChildItem $Dir "$App.*" | ForEach-Object {
    if ($PSVersionTable.PSVersion.Major -gt 5) { $_ = $_.Name } # Fix for pwsh

    # beautify
    $man = Scoop-ParseManifest "$Dir\$_"

    Scoop-WriteManifest "$Dir\$_" $man
}
