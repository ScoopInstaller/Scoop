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
        $app, $bucket, $version = parse_app $app
        if ($bucket) {
            $manifest = manifest $app $bucket
        } else {
            foreach ($tekcub in Get-LocalBucket) {
                $manifest = manifest $app $tekcub
                if ($manifest) {
                    $bucket = $tekcub
                    break
                }
            }
        }
        if (!$manifest) {
            # couldn't find app in buckets: check if it's a local path
            if (Test-Path $app) {
                $url = Convert-Path $app
                $app = appname_from_url $url
                $manifest = url_manifest $url
            } else {
                if (($app -match '\\/') -or $app.EndsWith('.json')) { $url = $app }
                $app = appname_from_url $app
            }
        }
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

function Get-HistoricalManifestFromDB($app, $bucket, $requestedVersion) {
    if (!(get_config USE_SQLITE_CACHE)) {
        return $null
    }
    
    # Import database functions if not already loaded
    if (!(Get-Command 'Get-ScoopDBItem' -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\database.ps1"
    }

    # First try exact match
    $dbResult = Get-ScoopDBItem -Name $app -Bucket $bucket -Version $requestedVersion
    if ($dbResult.Rows.Count -gt 0) {
        $row = $dbResult.Rows[0]
        ensure (usermanifestsdir) | Out-Null
        $tempManifestPath = "$(usermanifestsdir)\$app.json"
        $row.manifest | Out-UTF8File -FilePath $tempManifestPath
        return @{ path = $tempManifestPath; version = $requestedVersion; source = "sqlite_exact_match" }
    }

    # If no exact match, try to find best match from all versions of this app
    $allVersionsResult = Get-ScoopDBItem -Name $app -Bucket $bucket
    if ($allVersionsResult.Rows.Count -gt 0) {
        $availableVersions = $allVersionsResult.Rows | ForEach-Object { $_.version }
        $bestMatch = Find-BestVersionMatch -RequestedVersion $requestedVersion -AvailableVersions $availableVersions
        
        if ($bestMatch) {
            $matchedRow = $allVersionsResult.Rows | Where-Object { $_.version -eq $bestMatch } | Select-Object -First 1
            ensure (usermanifestsdir) | Out-Null
            $tempManifestPath = "$(usermanifestsdir)\$app.json"
            $matchedRow.manifest | Out-UTF8File -FilePath $tempManifestPath
            return @{ path = $tempManifestPath; version = $bestMatch; source = "sqlite_best_match" }
        }
    }

    return $null
}

function Get-HistoricalManifest($app, $bucket, $requestedVersion) {
    # First try to get historical manifest from SQLite
    $manifestFromDB = Get-HistoricalManifestFromDB $app $bucket $requestedVersion
    if ($manifestFromDB) {
        return $manifestFromDB
    }

    # Fall back to git history if not found in SQLite
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
        $gitLogOutput = Invoke-Git -Path $bucketDir -ArgumentList @('log', '--follow', '--format=format:%H%n%s', '--', $relativeManifestPath) # Removed 2>$null to see git errors

        if (!$gitLogOutput) {
            warn "No git history found for '$app' in bucket '$bucket' (file: $relativeManifestPath)."
            return $null
        }

        $foundVersions = [System.Collections.Generic.List[hashtable]]::new()
        $processedHashes = [System.Collections.Generic.HashSet[string]]::new()

        $versionsFoundForPreviousMinor = @{}
        $limitPreviousMinorCount = 5
        $requestedVersionParts = $requestedVersion -split '\.'
        $previousMinorVersionString = ''
        if ($requestedVersionParts.Count -ge 2 -and $requestedVersionParts[1] -match '^\d+$') {
            $currentMinor = [int]$requestedVersionParts[1]
            if ($currentMinor -gt 0) {
                $previousMinorVersionString = "$($requestedVersionParts[0]).$($currentMinor - 1)"
            }
        }

        $maxCommitsToProcess = 200 # Hard cap to prevent excessive runtimes

        for ($i = 0; $i -lt $gitLogOutput.Count; $i += 2) {
            if ($processedHashes.Count -ge $maxCommitsToProcess) {
                info "Processed $maxCommitsToProcess commits for $app. Stopping search to prevent excessive runtime."
                break
            }

            $hash = $gitLogOutput[$i]
            $subject = if (($i + 1) -lt $gitLogOutput.Count) { $gitLogOutput[$i + 1] } else { '' }

            if ([string]::IsNullOrWhiteSpace($hash) -or !$processedHashes.Add($hash)) {
                continue
            }

            $versionFromMessage = $null
            if ($subject -match "(?:'$app': Update to version |Update to |Release |Tag |v)($([char]34)?([0-9]+\.[0-9]+(?:\.[0-9]+){0,2}(?:[a-zA-Z0-9._+-]*))\1?)") {
                $versionFromMessage = $Matches[2]
            }

            if ($versionFromMessage -eq $requestedVersion) {
                info "Potential exact match '$versionFromMessage' found in commit message for $app (hash $hash). Verifying manifest..."
                $manifestContent = Invoke-Git -Path $bucketDir -ArgumentList @('show', "$hash`:$relativeManifestPath")
                if ($manifestContent -and ($LASTEXITCODE -eq 0)) {
                    $manifestObj = $null; try { $manifestObj = $manifestContent | ConvertFrom-Json -ErrorAction Stop } catch {}
                    if ($manifestObj -and $manifestObj.version -eq $requestedVersion) {
                        info "Exact version '$requestedVersion' for '$app' confirmed from manifest in commit $hash."
                        ensure (usermanifestsdir) | Out-Null
                        $tempManifestPath = "$(usermanifestsdir)\$app.json"
                        $manifestContent | Out-UTF8File -FilePath $tempManifestPath
                        return @{ path = $tempManifestPath; version = $requestedVersion; source = "git_commit_message:$hash" }
                    }
                }
            }

            $manifestContent = Invoke-Git -Path $bucketDir -ArgumentList @('show', "$hash`:$relativeManifestPath")
            if ($manifestContent -and ($LASTEXITCODE -eq 0)) {
                $manifestObj = $null;
                try {
                    $manifestObj = $manifestContent | ConvertFrom-Json -ErrorAction Stop
                } catch {
                    warn "Failed to parse manifest content from commit $hash for app $app. Skipping this commit."
                    # Consider logging $manifestContent if debugging is needed
                    continue # Skip to the next commit
                }

                if ($manifestObj -and $manifestObj.version) {
                    if ($manifestObj.version -eq $requestedVersion) {
                        info "Exact version '$requestedVersion' for '$app' found in manifest (commit $hash)."
                        ensure (usermanifestsdir) | Out-Null
                        $tempManifestPath = "$(usermanifestsdir)\$app.json"
                        $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
                        Set-Content -Path $tempManifestPath -Value $manifestContent -Encoding $utf8NoBomEncoding -NoNewline:$false
                        return @{ path = $tempManifestPath; version = $requestedVersion; source = "git_manifest:$hash" }
                    }
                    $foundVersions.Add(@{
                            version  = $manifestObj.version
                            hash     = $hash
                            manifest = $manifestContent
                        })

                    if ($previousMinorVersionString -ne '' -and $manifestObj.version.StartsWith($previousMinorVersionString)) {
                        if (!$versionsFoundForPreviousMinor.ContainsKey($previousMinorVersionString)) {
                            $versionsFoundForPreviousMinor[$previousMinorVersionString] = 0
                        }
                        $versionsFoundForPreviousMinor[$previousMinorVersionString]++
                        if ($versionsFoundForPreviousMinor[$previousMinorVersionString] -ge $limitPreviousMinorCount) {
                            info "Reached limit of $limitPreviousMinorCount versions for previous minor '$previousMinorVersionString' while checking $app. Stopping search."
                            break
                        }
                    }
                    if ($foundVersions.Count % 20 -eq 0 -and $foundVersions.Count -gt 0) {
                        info "Found $($foundVersions.Count) historical versions for $app so far..."
                    }
                }
            } elseif ($LASTEXITCODE -ne 0) {
                warn "git show $hash`:$relativeManifestPath failed for $app."
            }
        }

        if ($foundVersions.Count -eq 0) {
            warn "No valid historical versions found for '$app' in bucket '$bucket'."
            return $null
        }

        info "Found $($foundVersions.Count) distinct historical versions for '$app'. Finding best match for '$requestedVersion'..."

        $matchedVersionData = $null
        $bestMatchVersionString = Find-BestVersionMatch -RequestedVersion $requestedVersion -AvailableVersions ($foundVersions.version)

        if ($bestMatchVersionString) {
            $matchedVersionData = $foundVersions | Where-Object { $_.version -eq $bestMatchVersionString } | Select-Object -First 1
        }

        if ($matchedVersionData) {
            info "Best match for '$requestedVersion' is '$($matchedVersionData.version)' (commit $($matchedVersionData.hash))."
            ensure (usermanifestsdir) | Out-Null
            $tempManifestPath = "$(usermanifestsdir)\$app.json"
            $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
            Set-Content -Path $tempManifestPath -Value $matchedVersionData.manifest -Encoding $utf8NoBomEncoding -NoNewline:$false
            return @{
                path    = $tempManifestPath
                version = $matchedVersionData.version
                source  = "git_best_match:$($matchedVersionData.hash)"
            }
        } else {
            $availableVersionsForLog = ($foundVersions | Sort-Object {
                    try { [version]($_.version -replace '[^\d\.].*$', '') } catch { $_.version }
                } -Descending | Select-Object -First 10).version
            info "Could not find a suitable match for '$requestedVersion' for app '$app'. Available (latest 10): $($availableVersionsForLog -join ', ')"
        }

        return $null

    } catch {
        warn "Error searching git history for '$app': $($_.Exception.Message)"
        return $null
    }
}

function Find-BestVersionMatch($requestedVersion, $availableVersions) {
    <#
    .SYNOPSIS
        Find the best matching version from available versions
    .PARAMETER requestedVersion
        The version requested by user (e.g., "3.7", "3.7.4")
    .PARAMETER availableVersions
        Array of available version strings
    .RETURNS
        Best matching version string, or $null if no match
    #>

    if (!$availableVersions -or $availableVersions.Count -eq 0) {
        return $null
    }

    debug "Searching for version '$requestedVersion' among available versions: $($availableVersions -join ', ')"

    # First try exact match
    if ($availableVersions -contains $requestedVersion) {
        debug "Found exact match for version '$requestedVersion'"
        return $requestedVersion
    }

    # If no exact match, try to find compatible versions
    # Split requested version into parts
    $requestedParts = $requestedVersion -split '\.'

    # Filter versions that start with the requested version pattern
    $compatibleVersions = $availableVersions | Where-Object {
        $versionParts = $_ -split '\.'
        $isCompatible = $true

        for ($i = 0; $i -lt $requestedParts.Count; $i++) {
            if ($i -ge $versionParts.Count -or $versionParts[$i] -ne $requestedParts[$i]) {
                $isCompatible = $false
                break
            }
        }

        return $isCompatible
    }

    debug "Found $($compatibleVersions.Count) compatible versions: $($compatibleVersions -join ', ')"

    if ($compatibleVersions.Count -eq 0) {
        debug "No compatible versions found for '$requestedVersion'"
        return $null
    }

    # Sort compatible versions and return the highest one
    $sortedVersions = $compatibleVersions | Sort-Object {
        # Convert to version object for proper sorting
        try {
            [version]($_ -replace '[^\d\.].*$', '')  # Remove non-numeric suffixes for sorting
        } catch {
            $_  # Fallback to string sorting
        }
    } -Descending

    $selectedVersion = $sortedVersions[0]
    debug "Selected best match: '$selectedVersion' for requested version '$requestedVersion'"

    return $selectedVersion
}

function generate_user_manifest($app, $bucket, $version) {
    # 'autoupdate.ps1' 'buckets.ps1' 'manifest.ps1'
    $app, $manifest, $bucket, $null = Get-Manifest "$bucket/$app"
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }

    warn "Given version ($version) does not match manifest ($($manifest.version))"

    # Try to find the version using SQLite cache first, then git history
    if (get_config USE_SQLITE_CACHE) {
        info "Searching for version '$version' in cache..."
    } else {
        info "Searching for version '$version' in git history..."
    }
    
    $historicalResult = Get-HistoricalManifest $app $bucket $version

    if ($historicalResult) {
        if ($historicalResult.source -match '^sqlite') {
            info "Found version '$($historicalResult.version)' for '$app' in cache."
        } else {
            info "Found version '$($historicalResult.version)' for '$app' in git history (source: $($historicalResult.source))."
        }
        return $historicalResult.path
    }

    # Fallback to autoupdate generation
    warn "No historical version found. Attempting to generate manifest for '$app' ($version)"

    ensure (usermanifestsdir) | Out-Null
    $manifest_path = "$(usermanifestsdir)\$app.json"

    if (get_config USE_SQLITE_CACHE) {
        $cached_manifest = (Get-ScoopDBItem -Name $app -Bucket $bucket -Version $version).manifest
        if ($cached_manifest) {
            $cached_manifest | Out-UTF8File $manifest_path
            return $manifest_path
        }
    }

    if (!($manifest.autoupdate)) {
        abort "'$app' does not have autoupdate capability and no historical version found`r`ncouldn't find manifest for '$app@$version'"
    }

    try {
        Invoke-AutoUpdate $app $manifest_path $manifest $version $(@{ })
        return $manifest_path
    } catch {
        Write-Host -ForegroundColor DarkRed "Could not install $app@$version"

        # If autoupdate fails and we haven't tried git history yet, try it as final fallback
        if (!$historicalResult) {
            warn 'Autoupdate failed. Trying git history as final fallback...'
            $historicalResult = Get-HistoricalManifest $app $bucket $version
            if ($historicalResult) {
                warn "Using historical manifest as fallback for '$app' version '$($historicalResult.version)'"
                return $historicalResult.path
            }
        }
    }

    return $null
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }
function extract_dir($manifest, $arch) { arch_specific 'extract_dir' $manifest $arch }
function extract_to($manifest, $arch) { arch_specific 'extract_to' $manifest $arch }
