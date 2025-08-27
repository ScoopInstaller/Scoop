function manifest_path($app, $bucket) {
    (Get-ChildItem (Find-BucketDirectory $bucket) -Filter "$(sanitary_path $app).json" -Recurse).FullName
}

function parse_json($path) {
    if ($null -eq $path -or !(Test-Path $path)) { return $null }
    try {
        Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    } catch {
        warn "Error parsing JSON at '$path'."
    }
}

function url_manifest($url) {
    $str = $null
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $data = $wc.DownloadData($url)
        $str = (Get-Encoding($wc)).GetString($data)
    } catch [system.management.automation.methodinvocationexception] {
        warn "error: $($_.exception.innerexception.message)"
    } catch {
        throw
    }
    if (!$str) { return $null }
    try {
        $str | ConvertFrom-Json -ErrorAction Stop
    } catch {
        warn "Error parsing JSON at '$url'."
    }
}

function Get-Manifest($app) {
    $bucket, $manifest, $url = $null
    $app = $app.TrimStart('/')
    # check if app is a URL or UNC path
    if ($app -match '^(ht|f)tps?://|\\\\') {
        $url = $app
        $app = appname_from_url $url
        $manifest = url_manifest $url
    } else {
        # Check if the manifest is already installed
        if (installed $app) {
            $global = installed $app $true
            $ver = Select-CurrentVersion -AppName $app -Global:$global
            if (!$ver) {
                $app, $bucket, $ver = parse_app $app
                $ver = Select-CurrentVersion -AppName $app -Global:$global
            }
            $install_info_path = "$(versiondir $app $ver $global)\install.json"
            if (Test-Path $install_info_path) {
                $install_info = parse_json $install_info_path
                $bucket = $install_info.bucket
                if (!$bucket) {
                    $url = $install_info.url
                    if ($url -match '^(ht|f)tps?://|\\\\') {
                        $manifest = url_manifest $url
                    }
                    if (!$manifest) {
                        if (Test-Path $url) {
                            $manifest = parse_json $url
                        } else {
                            # Fallback to installed manifest
                            $manifest = installed_manifest $app $ver $global
                        }
                    }
                } else {
                    $manifest = manifest $app $bucket
                    if (!$manifest) {
                        $deprecated_dir = (Find-BucketDirectory -Name $bucket -Root) + '\deprecated'
                        $manifest = parse_json (Get-ChildItem $deprecated_dir -Filter "$(sanitary_path $app).json" -Recurse).FullName
                    }
                }
            }
        } else {
            $app, $bucket, $version = parse_app $app
            if ($bucket) {
                $manifest = manifest $app $bucket
            } else {
                $matched_buckets = @()
                foreach ($tekcub in Get-LocalBucket) {
                    $current_manifest = manifest $app $tekcub
                    if (!$manifest -and $current_manifest) {
                        $manifest = $current_manifest
                        $bucket = $tekcub
                    }
                    if ($current_manifest) {
                        $matched_buckets += $tekcub
                    }
                }
            }
            if (!$manifest) {
                # couldn't find app in buckets: check if it's a local path
                if (Test-Path $app) {
                    $url = Convert-Path $app
                    $app = appname_from_url $url
                    $manifest = parse_json $url
                } else {
                    if (($app -match '\\/') -or $app.EndsWith('.json')) { $url = $app }
                    $app = appname_from_url $app
                }
            }
        }
    }

    if ($matched_buckets.Length -gt 1) {
        warn "Multiple buckets contain manifest '$app', the current selection is '$bucket/$app'."
    }

    return $app, $manifest, $bucket, $url
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }
    parse_json (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if ($url) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $data = $wc.DownloadData($url)
        (Get-Encoding($wc)).GetString($data) | Out-UTF8File "$dir\manifest.json"
    } else {
        Copy-Item (manifest_path $app $bucket) "$dir\manifest.json"
    }
}

function installed_manifest($app, $version, $global) {
    parse_json "$(versiondir $app $version $global)\manifest.json"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    $file_content = $info | ConvertToPrettyJson # in 'json.ps1'
    [System.IO.File]::WriteAllLines("$dir\install.json", $file_content)
}

function install_info($app, $version, $global) {
    $path = "$(versiondir $app $version $global)\install.json"
    if (!(Test-Path $path)) { return $null }
    parse_json $path
}

function arch_specific($prop, $manifest, $architecture) {
    if ($manifest.architecture) {
        $val = $manifest.architecture.$architecture.$prop
        if ($val) { return $val } # else fallback to generic prop
    }

    if ($manifest.$prop) { return $manifest.$prop }
}

function Get-SupportedArchitecture($manifest, $architecture) {
    if ($architecture -eq 'arm64' -and ($manifest | ConvertToPrettyJson) -notmatch '[''"]arm64["'']') {
        # Windows 10 enables existing unmodified x86 apps to run on Arm devices.
        # Windows 11 adds the ability to run unmodified x64 Windows apps on Arm devices!
        # Ref: https://learn.microsoft.com/en-us/windows/arm/overview
        if ($WindowsBuild -ge 22000) {
            # Windows 11
            $architecture = '64bit'
        } else {
            # Windows 10
            $architecture = '32bit'
        }
    }
    if (![String]::IsNullOrEmpty((arch_specific 'url' $manifest $architecture))) {
        return $architecture
    }
}

function Get-RelativePathCompat($from, $to) {
    <#
    .SYNOPSIS
        Cross-platform compatible relative path function
    .DESCRIPTION
        Falls back to custom implementation for Windows PowerShell compatibility
    #>
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core/7+ - use built-in method
        try {
            return [System.IO.Path]::GetRelativePath($from, $to)
        } catch {
            # Fallback if method fails
        }
    }

    # Windows PowerShell compatible implementation
    $fromUri = New-Object System.Uri($from.TrimEnd('\') + '\')
    $toUri = New-Object System.Uri($to)

    if ($fromUri.Scheme -ne $toUri.Scheme) {
        return $to  # Cannot make relative path between different schemes
    }

    $relativeUri = $fromUri.MakeRelativeUri($toUri)
    $relativePath = [System.Uri]::UnescapeDataString($relativeUri.ToString())

    return $relativePath -replace '/', '\'
}

function Find-HistoricalManifestInCache($app, $bucket, $requestedVersion) {
    if (!(get_config USE_SQLITE_CACHE)) {
        return $null
    }

    # Return null if bucket is null or empty
    if (!$bucket) {
        return $null
    }

    # Import database functions if not already loaded
    if (!(Get-Command 'Get-ScoopDBItem' -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\database.ps1"
    }

    $dbResult = Get-ScoopDBItem -Name $app -Bucket $bucket -Version $requestedVersion

    # Strictly follow DB contract: must be DataTable with at least one row
    if (-not ($dbResult -is [System.Data.DataTable])) { return $null }
    if ($dbResult.Rows.Count -eq 0) { return $null }

    $manifestText = $dbResult.Rows[0]['manifest']
    if ([string]::IsNullOrWhiteSpace($manifestText)) { return $null }

    $manifestObj = $null
    try { $manifestObj = $manifestText | ConvertFrom-Json -ErrorAction Stop } catch {}
    $manifestVersion = if ($manifestObj -and $manifestObj.version) { $manifestObj.version } else { $requestedVersion }

    return @{ ManifestText = $manifestText; version = $manifestVersion; source = "sqlite_exact_match" }

    return $null
}

function Find-HistoricalManifestInGit($app, $bucket, $requestedVersion) {
    # Only proceed if git history is enabled
    if (!(get_config USE_GIT_HISTORY $true)) {
        return $null
    }

    if (!$bucket) {
        return $null
    }

    $bucketDir = Find-BucketDirectory $bucket -Root
    if (!(Test-Path "$bucketDir\.git")) {
        warn "Bucket '$bucket' is not a git repository. Cannot search historical versions."
        return $null
    }

    $manifestPath = "$app.json"
    $innerBucketDir = Find-BucketDirectory $bucket # Non-root path

    if (-not (Test-Path $innerBucketDir -PathType Container)) {
        warn "Could not find inner bucket directory for '$bucket' at '$innerBucketDir'."
        return $null
    }
    $relativeManifestPath = Get-RelativePathCompat $bucketDir (Join-Path $innerBucketDir $manifestPath)
    $relativeManifestPath = $relativeManifestPath -replace '\\', '/'

    try {
        # Prefer precise regex match on version line, fallback to -S literal
        $pattern = '"version"\s*:\s*"' + [regex]::Escape($requestedVersion) + '"'
        $commits = @()
        $outG = Invoke-Git -Path $bucketDir -ArgumentList @('log','--follow','-n','1','--format=%H','-G',$pattern,'--',$relativeManifestPath)
        if ($outG) { $commits = @($outG | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }

        if ($commits.Count -eq 0) {
            $searchLiteral = '"version": "' + $requestedVersion + '"'
            $outS = Invoke-Git -Path $bucketDir -ArgumentList @('log','--follow','-n','1','--format=%H','-S',$searchLiteral,'--',$relativeManifestPath)
            if ($outS) { $commits = @($outS | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
        }

        if ($commits.Count -eq 0) { return $null }

        $h = $commits[0]

        # First try parent snapshot (latest state before change), then the change itself
        foreach ($spec in @("$h^","$h")) {
            $content = Invoke-Git -Path $bucketDir -ArgumentList @('show', "$spec`:$relativeManifestPath")
            if (-not $content -or ($LASTEXITCODE -ne 0)) { continue }
            if ($content -is [Array]) { $content = $content -join "`n" }
            try {
                $obj = $content | ConvertFrom-Json -ErrorAction Stop
            } catch { continue }
            if ($obj -and $obj.version -eq $requestedVersion) {
                return @{ ManifestText = $content; version = $requestedVersion; source = "git_manifest:$spec" }
            }
        }

        # Fallback: iterate recent commits that touched the version string and validate
        $outAll = Invoke-Git -Path $bucketDir -ArgumentList @('log','--follow','--format=%H','-G',$pattern,'--',$relativeManifestPath)
        $allCommits = @()
        if ($outAll) { $allCommits = @($outAll | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }

        foreach ($c in $allCommits) {
            $content = Invoke-Git -Path $bucketDir -ArgumentList @('show', "$c`:$relativeManifestPath")
            if (-not $content -or ($LASTEXITCODE -ne 0)) { continue }
            if ($content -is [Array]) { $content = $content -join "`n" }
            try { $obj = $content | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            if ($obj -and $obj.version -eq $requestedVersion) {
                return @{ ManifestText = $content; version = $requestedVersion; source = "git_manifest:$c" }
            }
        }

        return $null
    } catch { return $null }
}

function Find-HistoricalManifest($app, $bucket, $version) {
    # Orchestrates historical manifest lookup using available providers (DB → Git)
    $result = $null

    if (get_config USE_SQLITE_CACHE) {
        $result = Find-HistoricalManifestInCache $app $bucket $version
        if ($result) {
            if ($result.ManifestText) {
                $path = Write-ManifestToUserCache -App $app -ManifestText $result.ManifestText
                return @{ path = $path; version = $result.version; source = $result.source }
            }
            return $result
        }
    }

    if (get_config USE_GIT_HISTORY $true) {
        $result = Find-HistoricalManifestInGit $app $bucket $version
        if ($result) {
            if ($result.ManifestText) {
                $path = Write-ManifestToUserCache -App $app -ManifestText $result.ManifestText
                return @{ path = $path; version = $result.version; source = $result.source }
            }
            return $result
        }
    }

    return $null
}


function generate_user_manifest($app, $bucket, $version) {
    # 'autoupdate.ps1' 'buckets.ps1' 'manifest.ps1'
    $app, $manifest, $bucket, $null = Get-Manifest "$bucket/$app"
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }

    # Try historical providers via orchestrator
    $historicalResult = Find-HistoricalManifest $app $bucket $version
    if ($historicalResult) { return $historicalResult.path }

    # No historical manifest; try autoupdate if available
    if (!($manifest.autoupdate)) {
        abort "Could not find manifest for '$app@$version' and no autoupdate is available"
    }

    ensure (usermanifestsdir) | Out-Null
    $manifest_path = "$(usermanifestsdir)\$app.json"

    try {
        Invoke-AutoUpdate $app $manifest_path $manifest $version $(@{ })
        return $manifest_path
    } catch {
        warn "Autoupdate failed for '$app@$version'"
        abort "Installation of '$app@$version' is not possible"
    }
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }
function extract_dir($manifest, $arch) { arch_specific 'extract_dir' $manifest $arch }
function extract_to($manifest, $arch) { arch_specific 'extract_to' $manifest $arch }

# Helper: write manifest text to user manifests cache directory and return path
function Write-ManifestToUserCache {
    param(
        [Parameter(Mandatory=$true, Position=0)][string]$App,
        [Parameter(Mandatory=$true, Position=1)][string]$ManifestText
    )
    ensure (usermanifestsdir) | Out-Null
    $tempManifestPath = "$(usermanifestsdir)\$App.json"
    $ManifestText | Out-UTF8File -FilePath $tempManifestPath
    return $tempManifestPath
}

