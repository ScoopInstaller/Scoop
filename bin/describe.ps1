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
$apps = @()
Get-ChildItem $dir "$App.json" | ForEach-Object {
    $json = parse_json "$dir\$($_.Name)"
    $apps += ,@(($_.Name -replace '\.json$', ''), $json)
}

$apps | ForEach-Object {
    $app, $json = $_
    write-host "$app`: " -nonewline

    if(!$json.homepage) {
        write-host "`nNo homepage set." -fore red
        return
    }
    # get description from homepage
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $home_html = $wc.downloadstring($json.homepage)
    } catch {
        write-host "`n$($_.exception.message)" -fore red
        return
    }

    $description, $descr_method = find_description $json.homepage $home_html
    if(!$description) {
        write-host -fore red "`nDescription not found ($($json.homepage))"
        return
    }

    $description = clean_description $description

    write-host "(found by $descr_method)"
    write-host "  ""$description""" -fore green
}
