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
    Downloaded files will not be deleted after script finish.
    Should not be used, because check should be used for downloading actual version of file (as normal user, not finding in some document from vendors, which could be damaged / wrong (Example: Slack@3.3.1 ScoopInstaller/Extras#1192)), not some previously downloaded.
.EXAMPLE
    PS BUCKETROOT> .\bin\checkhashes.ps1
    Check all manifests for hash mismatch.
.EXAMPLE
    PS BUCKETROOT> .\bin\checkhashes.ps1 MANIFEST -Update
    Check MANIFEST and Update if there are some wrong hashes.
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
    [String] $Dir,
    [Switch] $Update,
    [Switch] $ForceUpdate,
    [Switch] $SkipCorrect,
    [Alias('k')]
    [Switch] $UseCache
)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\autoupdate.ps1"
. "$PSScriptRoot\..\lib\json.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\download.ps1"

$Dir = Convert-Path $Dir
if ($ForceUpdate) { $Update = $true }
# Cleanup
if (!$UseCache) { Remove-Item "$cachedir\*HASH_CHECK*" -Force }

function err ([String] $name, [String[]] $message) {
    Write-Host "$name`: " -ForegroundColor Red -NoNewline
    Write-Host ($message -join "`r`n") -ForegroundColor Red
}

$MANIFESTS = [System.Collections.ArrayList]::new()
foreach ($single in Get-ChildItem $Dir -Filter "$App.json" -Recurse) {
    $name = $single.BaseName
    $file = $single.FullName
    $manifest = parse_json $file

    # Skip nighly manifests, since their hash validation is skipped
    if ($manifest.version -eq 'nightly') { continue }

    $urls = [System.Collections.ArrayList]::new()
    $hashes = [System.Collections.ArrayList]::new()

    if ($manifest.url) {
        $manifest.url | ForEach-Object { $urls.Add($_) }
        $manifest.hash | ForEach-Object { $hashes.Add($_) }
    } elseif ($manifest.architecture) {
        # First handle 64bit
        script:url $manifest '64bit' | ForEach-Object { $urls.Add($_) }
        hash $manifest '64bit' | ForEach-Object { $hashes.Add($_) }

        script:url $manifest '64bit-v2' | ForEach-Object { $urls.Add($_) }
        hash $manifest '64bit-v2' | ForEach-Object { $hashes.Add($_) }

        script:url $manifest '64bit-v3' | ForEach-Object { $urls.Add($_) }
        hash $manifest '64bit-v3' | ForEach-Object { $hashes.Add($_) }

        script:url $manifest '64bit-v4' | ForEach-Object { $urls.Add($_) }
        hash $manifest '64bit-v4' | ForEach-Object { $hashes.Add($_) }

        script:url $manifest '32bit' | ForEach-Object { $urls.Add($_) }
        hash $manifest '32bit' | ForEach-Object { $hashes.Add($_) }

        script:url $manifest 'arm64' | ForEach-Object { $urls.Add($_) }
        hash $manifest 'arm64' | ForEach-Object { $hashes.Add($_) }
    } else {
        err $name 'Manifest does not contain URL property.'
        continue
    }

    # Number of URLS and Hashes is different
    if ($urls.Length -ne $hashes.Length) {
        err $name 'URLS and hashes count mismatch.'
        continue
    }

    $MANIFESTS.Add(@{
            app      = $name
            file     = $file
            manifest = $manifest
            urls     = $urls
            hashes   = $hashes
        })
}

# clear any existing events
Get-Event | ForEach-Object { Remove-Event $_.SourceIdentifier }

foreach ($current in $MANIFESTS) {
    $count = 0
    # Array of indexes mismatched hashes.
    $mismatched = [System.Collections.ArrayList]::new()
    # Array of computed hashes
    $actuals = [System.Collections.ArrayList]::new()

    $current.urls | ForEach-Object {
        $algorithm, $expected = get_hash $current.hashes[$count]
        if ($UseCache) {
            $version = $current.manifest.version
        } else {
            $version = 'HASH_CHECK'
        }

        Invoke-CachedDownload $current.app $version $_ $null $null -use_cache:$UseCache

        $to_check = cache_path $current.app $version $_
        $actual_hash = (Get-FileHash -Path $to_check -Algorithm $algorithm).Hash.ToLower()

        # Append type of algorithm to both expected and actual if it's not sha256
        if ($algorithm -ne 'sha256') {
            $actual_hash = "$algorithm`:$actual_hash"
            $expected = "$algorithm`:$expected"
        }

        $actuals.Add($actual_hash)
        if ($actual_hash -ne $expected) {
            $mismatched.Add($count)
        }
        $count++
    }

    if ($mismatched.Length -eq 0 ) {
        if (!$SkipCorrect) {
            Write-Host "$($current.app): " -NoNewline
            Write-Host 'OK' -ForegroundColor Green
        }
    } else {
        Write-Host "$($current.app): " -NoNewline
        Write-Host 'Mismatch found ' -ForegroundColor Red
        $mismatched | ForEach-Object {
            $file = cache_path $current.app $version $current.urls[$_]
            Write-Host "`tURL:`t`t$($current.urls[$_])"
            if (Test-Path $file) {
                Write-Host "`tFirst bytes:`t$((get_magic_bytes_pretty $file ' ').ToUpper())"
            }
            Write-Host "`tExpected:`t$($current.hashes[$_])" -ForegroundColor Green
            Write-Host "`tActual:`t`t$($actuals[$_])" -ForegroundColor Red
        }
    }

    if ($Update) {
        if ($current.manifest.url -and $current.manifest.hash) {
            $current.manifest.hash = $actuals
        } else {
            $platforms = ($current.manifest.architecture | Get-Member -MemberType NoteProperty).Name
            # Defaults to zero, don't know which architecture is available yet
            $64bit_v4_count = $64bit_v3_count = $64bit_v2_count = $64bit_count = $32bit_count = $arm64_count = 0

            # 64bit is checked, downloaded and added first
            if ($platforms.Contains('64bit')) {
                $64bit_count = $current.manifest.architecture.'64bit'.hash.Count
                $current.manifest.architecture.'64bit'.hash = $actuals[0..($64bit_count - 1)]
            }
            if ($platforms.Contains('64bit-v2')) {
                $64bit_v2_count = $current.manifest.architecture.'64bit-v2'.hash.Count
                $current.manifest.architecture.'64bit-v2'.hash = $actuals[0..($64bit_v2_count - 1)]
            }
            if ($platforms.Contains('64bit-v3')) {
                $64bit_v3_count = $current.manifest.architecture.'64bit-v3'.hash.Count
                $current.manifest.architecture.'64bit-v3'.hash = $actuals[0..($64bit_v3_count - 1)]
            }
            if ($platforms.Contains('64bit-v4')) {
                $64bit_v4_count = $current.manifest.architecture.'64bit-v4'.hash.Count
                $current.manifest.architecture.'64bit-v4'.hash = $actuals[0..($64bit_v4_count - 1)]
            }
            if ($platforms.Contains('32bit')) {
                $32bit_count = $current.manifest.architecture.'32bit'.hash.Count
                $current.manifest.architecture.'32bit'.hash = $actuals[($64bit_count)..($64bit_count + $32bit_count - 1)]
            }
            if ($platforms.Contains('arm64')) {
                $arm64_count = $current.manifest.architecture.'arm64'.hash.Count
                $current.manifest.architecture.'arm64'.hash = $actuals[($64bit_count + $32bit_count)..($64bit_count + $32bit_count + $arm64_count - 1)]
            }
        }

        Write-Host "Writing updated $($current.app) manifest" -ForegroundColor DarkGreen

        $current.manifest = $current.manifest | ConvertToPrettyJson
        $path = Convert-Path $current.file
        [System.IO.File]::WriteAllLines($path, $current.manifest)
    }
}
