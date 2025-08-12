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

function Get-HistoricalManifestFromDB($app, $bucket, $requestedVersion) {
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

    # First try exact match
    $dbResult = Get-ScoopDBItem -Name $app -Bucket $bucket -Version $requestedVersion
    if ($dbResult.Rows.Count -gt 0) {
        $row = $dbResult.Rows[0]
        ensure (usermanifestsdir) | Out-Null
        $tempManifestPath = "$(usermanifestsdir)\$app.json"
        $row.manifest | Out-UTF8File -FilePath $tempManifestPath

        # Parse the manifest to get its actual version
        $manifest = $row.manifest | ConvertFrom-Json
        $manifestVersion = if ($manifest.version) { $manifest.version } else { $requestedVersion }
        return @{ path = $tempManifestPath; version = $manifestVersion; source = "sqlite_exact_match" }
    }

    # No exact match found, return null (no compatibility matching)

    return $null
}

function Get-HistoricalManifestFromGitHistory($app, $bucket, $requestedVersion) {
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
                    if ($manifestContent -is [Array]) {
                        $manifestContent = $manifestContent -join "`n"
                    }
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
                if ($manifestContent -is [Array]) {
                    $manifestContent = $manifestContent -join "`n"
                }
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
                        if ($PSVersionTable.PSVersion.Major -ge 6) {
                            $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($false)
                            Set-Content -Path $tempManifestPath -Value $manifestContent -Encoding $utf8NoBomEncoding -NoNewline:$false
                        } else {
                            # PowerShell 5 compatibility
                            $manifestContent | Out-UTF8File -FilePath $tempManifestPath
                        }
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

        # No exact match found - display all available versions to help user choose
        $allAvailableVersions = ($foundVersions | Sort-Object {
                try { [version]($_.version -replace '[^\d\.].*$', '') } catch { $_.version }
            } -Descending).version

        Write-Host ""
        Write-Host "No exact match found for version '$requestedVersion' for app '$app'."
        Write-Host "Available versions in git history (newest to oldest):"
        Write-Host ""

        # Group versions for better display
        $displayCount = [Math]::Min(50, $allAvailableVersions.Count)  # Show up to 50 versions
        for ($i = 0; $i -lt $displayCount; $i++) {
            Write-Host "  $($allAvailableVersions[$i])"
        }

        if ($allAvailableVersions.Count -gt $displayCount) {
            Write-Host "  ... and $($allAvailableVersions.Count - $displayCount) more versions"
        }

        Write-Host ""
        Write-Host "To install a specific version, use: scoop install $app@<version>"
        Write-Host ""

        return $null

    } catch {
        warn "Error searching git history for '$app': $($_.Exception.Message)"
        return $null
    }
}


function generate_user_manifest($app, $bucket, $version) {
    # 'autoupdate.ps1' 'buckets.ps1' 'manifest.ps1'
    $app, $manifest, $bucket, $null = Get-Manifest "$bucket/$app"
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }

    warn "Given version ($version) does not match manifest ($($manifest.version))"

    $historicalResult = $null

    # Try SQLite cache first if enabled
    if (get_config USE_SQLITE_CACHE) {
        info "Searching for version '$version' in cache..."
        $historicalResult = Get-HistoricalManifestFromDB $app $bucket $version
        if ($historicalResult) {
            info "Found version '$($historicalResult.version)' for '$app' in cache."
            return $historicalResult.path
        }
    }

    # Try git history if cache didn't find it
    if (!$historicalResult) {
        info "Searching for version '$version' in git history..."
        $historicalResult = Get-HistoricalManifestFromGitHistory $app $bucket $version
        if ($historicalResult) {
            return $historicalResult.path
        }
    }

    # If no historical version found, provide helpful guidance
    if (!$historicalResult) {
        # Try to provide additional context about what versions are available
        $currentVersion = $manifest.version
        if ($currentVersion) {
            info "Current version available: $currentVersion"
            info "To install the current version, use: scoop install $app"
        }

        # Check if we have autoupdate capability for fallback
        if ($manifest.autoupdate) {
            info "This app supports autoupdate - attempting to generate manifest for version $version"
        } else {
            warn "'$app' does not have autoupdate capability."
            Write-Host "Available options:"
            Write-Host "  1. Install current version: scoop install $app"
            Write-Host "  2. Check if the requested version exists in other buckets"
            Write-Host "  3. Contact the bucket maintainer to add historical version support"
            Write-Host ""
            abort "Could not find manifest for '$app@$version' and no autoupdate available"
        }
    }

    # Fallback to autoupdate generation
    warn "No historical version found. Attempting to generate manifest for '$app' ($version)"

    ensure (usermanifestsdir) | Out-Null
    $manifest_path = "$(usermanifestsdir)\$app.json"

    # Check SQLite cache for exact cached manifest (this is different from historical search)
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
        Write-Host -ForegroundColor Yellow "Autoupdate failed for version $version"

        # Provide helpful guidance when autoupdate fails
        Write-Host "Possible reasons:"
        Write-Host "  - Version $version may not exist or be available for download"
        Write-Host "  - Download URLs may have changed or be inaccessible"
        Write-Host "  - The version format may be incompatible with autoupdate patterns"
        Write-Host ""
        Write-Host "Suggestions:"
        Write-Host "  1. Install current version: scoop install $app"
        Write-Host "  2. Try a different version that was shown in the available list"
        Write-Host "  3. Check the app's official releases or download page"
        Write-Host ""

        # If autoupdate fails and we haven't tried git history yet, try it as final fallback
        if (!$historicalResult -and !(get_config USE_SQLITE_CACHE)) {
            warn 'Autoupdate failed. Trying git history as final fallback...'
            $fallbackResult = Get-HistoricalManifestFromGitHistory $app $bucket $version
            if ($fallbackResult) {
                warn "Using historical manifest as fallback for '$app' version '$($fallbackResult.version)'"
                return $fallbackResult.path
            }
        }

        # Final failure - provide comprehensive guidance
        Write-Host -ForegroundColor Red "All attempts to find or generate manifest for '$app@$version' failed."
        abort "Installation of '$app@$version' is not possible"
    }

    return $null
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }
function extract_dir($manifest, $arch) { arch_specific 'extract_dir' $manifest $arch }
function extract_to($manifest, $arch) { arch_specific 'extract_to' $manifest $arch }
