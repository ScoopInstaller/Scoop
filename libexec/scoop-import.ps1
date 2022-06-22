# Usage: scoop import <path/url to scoopfile.json>
# Summary: Imports apps, buckets and configs from a Scoopfile in JSON format

param([Parameter(Mandatory)][String]$scoopfile)

. "$PSScriptRoot\..\lib\manifest.ps1"

$import = $null
$bucket_names = @()
$def_arch = default_architecture

if (Test-Path $scoopfile) {
    $import = parse_json $scoopfile
} elseif ($scoopfile -match '^(ht|f)tps?://|\\\\') {
    $import = url_manifest $scoopfile
}

if (!$import) { abort 'Input file not a valid JSON.' }

$import.config.PSObject.Properties | ForEach-Object {
    set_config $_.Name $_.Value | Out-Null
    Write-Host "'$($_.Name)' has been set to '$($_.Value)'"
}

$import.buckets | ForEach-Object {
    add_bucket $_.Name $_.Source | Out-Null
    $bucket_names += $_.Name
}

$import.apps | ForEach-Object {
    $info = $_.Info -Split ', '
    $global = if ('Global install' -in $info) {
        ' --global'
    } else {
        ''
    }
    $arch = if ('64bit' -in $info -and '32bit' -eq $def_arch) {
        ' --arch 64bit'
    } elseif ('32bit' -in $info -and '64bit' -eq $def_arch) {
        ' --arch 32bit'
    } else {
        ''
    }

    $app = if ($_.Source -in $bucket_names) {
        "$($_.Source)/$($_.Name)"
    } elseif ($_.Source -eq '<auto-generated>') {
        "$($_.Name)@$($_.Version)"
    } else {
        $_.Source
    }

    & "$PSScriptRoot\scoop-install.ps1" $app$global$arch

    if ('Held package' -in $info) {
        & "$PSScriptRoot\scoop-hold.ps1" $($_.Name)$global
    }
}
