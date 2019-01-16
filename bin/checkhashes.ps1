<#
.SYNOPSIS
    Check if ALL urls inside manifest have correct hashes.
.PARAMETER App
    Manifest to be checked.
    Wildcard is supported.
.PARAMETER Dir
    Where to search for manifest(s).
.PARAMETER Update
    When there are mismatched hashes, manifest will be updated.
.PARAMETER ForceUpdate
    Manifest will be updated all the time. Not only when there are mismatched hashes.
.PARAMETER SkipCorrect
    Manifests without mismatch will not be shown.
.PARAMETER UseCache
    Downloaded files woun't be deleted after script finish.
    Should not be used, because check should be used for downloading actual version of file (as normal user, not finding in some document from vendors, which could be damaged / wrong (Example: Slack@3.3.1 lukesampson/scoop-extras#1192)), not some previously downloaded.
.EXAMPLE
    PS BUCKETDIR> .\bin\checkhashes.ps1
    Check all manifests for hash mismatch.
.EXAMPLE
    PS BUCKETDIR> .\bin\checkhashes.ps1 MANIFEST -Update
    Check MANIFEST and Update if there are some wrong hashes.
#>
param(
    [String] $App = '*',
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [String] $Dir = "$PSScriptRoot\..\bucket",
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipCorrect,
    [Alias('k')]
    [Switch] $UseCache
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\config.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\autoupdate.ps1"
. "$PSScriptRoot\..\lib\json.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\unix.ps1"

$Dir = Resolve-Path $Dir
if ($ForceUpdate) { $Update = $true }
# Cleanup
if (!$UseCache) { scoop cache rm '*HASH_CHECK*' }

# get apps to check
$Queue = @()
Get-ChildItem $Dir "$App.json" | ForEach-Object {
    $manifest = parse_json "$Dir\$($_.Name)"
    # Skip nighly manfiests, since their hash validation is skipped
    if (!($manifest.version -eq 'nightly')) {
        $Queue += , @($_.Name, $manifest)
    }
}

# clear any existing events
Get-Event | ForEach-Object {
    Remove-Event $_.SourceIdentifier
}

function err ([String] $name, [String[]] $message) {
    Write-Host "$name`:" -ForegroundColor Red -NoNewline
    Write-Host ($message -join "`r`n") -ForegroundColor Red
}

$original = use_any_https_protocol

$MANIFESTS = @()
$MANIFESTS += $Queue | ForEach-Object {
    $name, $manifest = $_
    $urls = @()
    $hashes = @()

    if ($manifest.architecture) {
        # First handle 64bit
        url $manifest '64bit' | ForEach-Object { $urls += $_ }
        hash $manifest '64bit' | ForEach-Object { $hashes += $_ }
        url $manifest '32bit' | ForEach-Object { $urls += $_ }
        hash $manifest '32bit' | ForEach-Object { $hashes += $_ }
    } elseif ($manifest.url) {
        $manifest.url | ForEach-Object { $urls += $_ }
        $manifest.hash | ForEach-Object { $hashes += $_ }
    } else {
        continue
    }

    # Number of URLS and Hashes is different
    if (!($urls.Length -eq $hashes.Length)) { err $name 'URLS and hashes count mismatch.' }

    $man = New-Object psobject @{
        app    = (strip_ext $name)
        json   = $manifest
        urls   = $urls
        hashes = $hashes
    }

    return $man
}

$MANIFESTS | ForEach-Object {
    $current = $_
    $count = 0
    # Array of indexes mismatched hashes.
    $mismatched = @()
    $actuals = @()

    $current.urls | ForEach-Object {
        $expected_hash = $current.hashes[$count]
        $algorithm = 'sha256'
        $name = $current.app
        $version = 'HASH_CHECK'
        $tmp = $expected_hash.Split(':')

        if ($tmp.Length -eq 2) {
            $algorithm = $tmp[0]
            $expected_hash = $tmp[1]
        }

        dl_with_cache $name $version $_ $null $null -use_cache:$UseCache

        $to_check = fullpath (cache_path $name $version $_)
        $actual_hash = (Get-FileHash $to_check -Algorithm $algorithm).Hash.ToLower()
        $actuals += $actual_hash
        if (!($actual_hash -eq $expected_hash)) {
            $mismatched += $count
            if (!$SkipCorrect) { Write-Host 'Wrong' -ForegroundColor Red }
        } else {
            if (!$SkipCorrect) { Write-Host 'OK' -ForegroundColor Green }
        }
        $count++
    }

    if ($mismatched.Length -eq 0 ) {
        if (!$SkipCorrect) {
            Write-Host "$($current.app): " -NoNewline
            Write-Host 'OK' -ForegroundColor Green
        }
    } else {
        Write-Host "$($current.app): "
        $mismatched | ForEach-Object {
            Write-Host "`t$($current.urls[$_])" -ForegroundColor Red
            Write-Host "`t`tExp:" $current.hashes[$_] -ForegroundColor Green
            Write-Host "`t`tAct:" $actuals[$_] -ForegroundColor Red
        }
    }

    if ($Update) {
        $path = Resolve-Path "$Dir\$($current.app).json"
        $json = parse_json $path

        if ($json.url -and $json.hash) {
            $json.hash = $actuals
        } else {
            $platforms = ($json.architecture | Get-Member -MemberType NoteProperty).Name
            # Defaults to zero, don't know, which architecture is available
            $64bit_count = 0
            $32bit_count = 0
            if ($platforms.Contains('64bit')) {
                $64bit_count = $json.architecture.'64bit'.hash.Count
                # 64bit is get, donwloaded and added first
                $json.architecture.'64bit'.hash = $actuals[0..($64bit_count - 1)]
            }
            if ($platforms.Contains('32bit')) {
                $32bit_count = $json.architecture.'32bit'.hash.Count
                $json.architecture.'32bit'.hash = $actuals[($64bit_count)..($32bit_count)]
            }
        }

        Write-Host "Writing updated $($current.app) manifest" -ForegroundColor DarkGreen

        $json = $json | ConvertToPrettyJson
        [System.IO.File]::WriteAllLines($path, $json)
    }
}
