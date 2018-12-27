<#
.SYNOPSIS
    Search for application description on homepage.
.PARAMETER App
    Manifest name to search.
    Placeholders are supported.
.PARAMETER Dir
    Where to search for manifest(s).
#>
param(
    [String] $App = '*',
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        }
        $true
    })]
    [String] $Dir = "$PSScriptRoot\..\bucket"
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\description.ps1"

$Dir = Resolve-Path $Dir

# get apps to check
$Queue = @()
Get-ChildItem $dir "$App.json" | ForEach-Object {
    $manifest = parse_json "$Dir\$($_.Name)"
    $Queue += ,@(($_.Name -replace '\.json$', ''), $manifest)
}

$Queue | ForEach-Object {
    $name, $manifest = $_
    write-host "$name`: " -nonewline

    if(!$manifest.homepage) {
        write-host "`nNo homepage set." -fore red
        return
    }
    # get description from homepage
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.downloadstring($manifest.homepage)
    } catch {
        write-host "`n$($_.exception.message)" -fore red
        return
    }

    $description, $descr_method = find_description $manifest.homepage $home_html
    if(!$description) {
        write-host -fore red "`nDescription not found ($($manifest.homepage))"
        return
    }

    $description = clean_description $description

    write-host "(found by $descr_method)"
    write-host "  ""$description""" -fore green
}
