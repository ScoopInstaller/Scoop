# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#   - With 'use_sqlite_cache' enabled, [query] is partially matched against app names, binaries, and shortcuts.
#   - Without 'use_sqlite_cache', [query] is matched against app names and binaries via:
#       * A JSON-based binary-index cache (when fresh) for fast substring matching (~200ms), or
#       * The original regex full-scan as fallback (~3s).
#   - Queries containing regex metacharacters (.+*?|[](){}^$\ ) skip the cache and use regex directly.
# Without [query], shows all the available apps.
param($query)

. "$PSScriptRoot\..\lib\manifest.ps1" # 'manifest'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-LatestVersion'
. "$PSScriptRoot\..\lib\download.ps1"

$list = [System.Collections.Generic.List[PSCustomObject]]::new()

# === Search index cache (JSON-based, faster than SQLite) ===
$searchCachePath = Join-Path $scoopdir 'search-cache.json'
$searchIndexApps = $null
$searchIndexBins = $null

function init_search_cache {
    if (-not (Test-Path $searchCachePath)) { return $false }
    try {
        $cache = Get-Content $searchCachePath -Raw | ConvertFrom-Json -ErrorAction Stop
        $cacheAge = (Get-Date) - [datetime]::Parse($cache.timestamp)
        if ($cacheAge.TotalHours -ge 24) { return $false }
        # Cross-check file count and last-write fingerprint for staleness
        $currentCount = 0; $currentMaxWrite = [datetime]::MinValue
        Get-LocalBucket | ForEach-Object {
            $dir = Find-BucketDirectory $_
            $items = Get-ChildItem $dir -Filter '*.json' -Recurse -ErrorAction SilentlyContinue
            $currentCount += $items.Count
            foreach ($item in $items) {
                if ($item.LastWriteTimeUtc -gt $currentMaxWrite) { $currentMaxWrite = $item.LastWriteTimeUtc }
            }
        }
        if ($cache.fileCount -ne $currentCount) { return $false }
        if ($cache.maxWriteUtc -ne $currentMaxWrite.ToString('o')) { return $false }
        $script:searchIndexApps = @{}
        foreach ($prop in $cache.apps.PSObject.Properties) {
            $entries = @()
            foreach ($entry in $prop.Value) {
                $entries += @{ path = $entry.path; bucket = $entry.bucket }
            }
            $script:searchIndexApps[$prop.Name] = $entries
        }
        $script:searchIndexBins = @{}
        foreach ($prop in $cache.bins.PSObject.Properties) {
            $script:searchIndexBins[$prop.Name] = @($prop.Value)
        }
        return $true
    } catch { return $false }
}

function build_search_cache {
    $allPathsByBucket = @{}
    $maxWriteUtc = [datetime]::MinValue
    Get-LocalBucket | ForEach-Object {
        $dir = Find-BucketDirectory $_
        $items = Get-ChildItem $dir -Filter '*.json' -Recurse -ErrorAction SilentlyContinue
        $paths = @($items | ForEach-Object { $_.FullName })
        foreach ($item in $items) {
            if ($item.LastWriteTimeUtc -gt $maxWriteUtc) { $maxWriteUtc = $item.LastWriteTimeUtc }
        }
        if ($paths.Count -gt 0) { $allPathsByBucket[$_] = $paths }
    }
    $totalCount = ($allPathsByBucket.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    $newApps = @{}
    $newBins = @{}

    foreach ($bucket in $allPathsByBucket.Keys) {
        foreach ($filePath in $allPathsByBucket[$bucket]) {
            $appName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
            if (-not $newApps.ContainsKey($appName)) { $newApps[$appName] = @() }
            $newApps[$appName] += @{ path = $filePath; bucket = $bucket }
            try {
                $manifest = Get-Content -Path $filePath -Raw | ConvertFrom-Json -ErrorAction Stop
                if (-not $manifest.bin) { continue }
                foreach ($binEntry in $manifest.bin) {
                    $exe = $null; $alias = $null
                    if ($binEntry -is [System.Object[]]) {
                        $exe = $binEntry[0]
                        $alias = if ($binEntry.Count -gt 1) { $binEntry[1] } else { $null }
                    } else { $exe = $binEntry }
                    $exeName = [System.IO.Path]::GetFileNameWithoutExtension([string]$exe).ToLower()
                    if ($exeName) {
                        if (-not $newBins.ContainsKey($exeName)) { $newBins[$exeName] = @() }
                        if ($appName -notin $newBins[$exeName]) { $newBins[$exeName] += $appName }
                    }
                    if ($alias) {
                        $aliasName = $alias.ToLower()
                        if ($aliasName) {
                            if (-not $newBins.ContainsKey($aliasName)) { $newBins[$aliasName] = @() }
                            if ($appName -notin $newBins[$aliasName]) { $newBins[$aliasName] += $appName }
                        }
                    }
                }
            } catch { Write-Debug "cache-build parse failed for $($filePath): $($_.Exception.Message)" }
        }
    }
    $cacheData = [PSCustomObject]@{ timestamp = (Get-Date).ToString('o'); fileCount = $totalCount; maxWriteUtc = $maxWriteUtc.ToString('o'); apps = [PSCustomObject]$newApps; bins = [PSCustomObject]$newBins }
    $cacheData | ConvertTo-Json -Compress -Depth 4 | Set-Content $searchCachePath -Encoding UTF8
    $script:searchIndexApps = $newApps
    $script:searchIndexBins = $newBins
    return $true
}

function search_by_index($query) {
    if (-not $query) { return }
    $matchedByName = @{}
    $matchedByBin = @{}

    # Phase 1: Search app names (case-insensitive substring)
    foreach ($appName in $searchIndexApps.Keys) {
        if ($appName.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $matchedByName[$appName] = $true
        }
    }

    # Phase 2: Search binary names — only for apps not already matched by name
    foreach ($binName in $searchIndexBins.Keys) {
        if ($binName.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            foreach ($appName in $searchIndexBins[$binName]) {
                if (-not $matchedByName.ContainsKey($appName) -and -not $matchedByBin.ContainsKey($appName)) {
                    $matchedByBin[$appName] = $true
                }
            }
        }
    }

    # Display: name-matched apps get empty binaries (matching stock), binary-only get matching binaries
    foreach ($appName in $matchedByName.Keys) {
        foreach ($entry in $searchIndexApps[$appName]) {
            try {
                $manifest = Get-Content -Path $entry.path -Raw | ConvertFrom-Json -ErrorAction Stop
                if (-not $manifest) { continue }
                $list.Add([PSCustomObject]@{ Name = $appName; Version = $manifest.version; Source = $entry.bucket; Binaries = '' })
            } catch { Write-Debug "index search parse failed for $($entry.path): $($_.Exception.Message)" }
        }
    }

    foreach ($appName in $matchedByBin.Keys) {
        foreach ($entry in $searchIndexApps[$appName]) {
            try {
                $manifest = Get-Content -Path $entry.path -Raw | ConvertFrom-Json -ErrorAction Stop
                $binaries = ''
                $binMatches = @()
                if (-not $manifest) { continue }
                if ($manifest.bin) {
                    foreach ($binEntry in $manifest.bin) {
                        $exe = $null; $alias = $null
                        if ($binEntry -is [System.Object[]]) {
                            $exe = $binEntry[0]
                            $alias = if ($binEntry.Count -gt 1) { $binEntry[1] } else { $null }
                        } else { $exe = $binEntry }
                        $exeName = [System.IO.Path]::GetFileNameWithoutExtension([string]$exe)
                        if ($exeName.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                            ($alias -and $alias.IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0)) {
                            $binMatches += [System.IO.Path]::GetFileName([string]$exe)
                        }
                    }
                    if ($binMatches) { $binaries = $binMatches -join ' | ' }
                }
                $list.Add([PSCustomObject]@{ Name = $appName; Version = $manifest.version; Source = $entry.bucket; Binaries = $binaries })
            } catch { Write-Debug "index search parse failed for $($entry.path): $($_.Exception.Message)" }
        }
    }
}

function bin_match($manifest, $query) {
    if (!$manifest.bin) { return $false }
    $bins = foreach ($bin in $manifest.bin) {
        $exe, $alias, $args = $bin
        $fname = Split-Path $exe -Leaf -ErrorAction Stop

        if ((strip_ext $fname) -match $query) { $fname }
        elseif ($alias -match $query) { $alias }
    }

    if ($bins) { return $bins }
    else { return $false }
}

function bin_match_json($json, $query) {
    [System.Text.Json.JsonElement]$bin = [System.Text.Json.JsonElement]::new()
    if (!$json.RootElement.TryGetProperty('bin', [ref] $bin)) { return $false }
    $bins = @()
    if ($bin.ValueKind -eq [System.Text.Json.JsonValueKind]::String -and [System.IO.Path]::GetFileNameWithoutExtension($bin) -match $query) {
        $bins += [System.IO.Path]::GetFileName($bin)
    } elseif ($bin.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($subbin in $bin.EnumerateArray()) {
            if ($subbin.ValueKind -eq [System.Text.Json.JsonValueKind]::String -and [System.IO.Path]::GetFileNameWithoutExtension($subbin) -match $query) {
                $bins += [System.IO.Path]::GetFileName($subbin)
            } elseif ($subbin.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
                if ([System.IO.Path]::GetFileNameWithoutExtension($subbin[0]) -match $query) {
                    $bins += [System.IO.Path]::GetFileName($subbin[0])
                } elseif ($subbin.GetArrayLength() -ge 2 -and $subbin[1] -match $query) {
                    $bins += $subbin[1]
                }
            }
        }
    }

    if ($bins) { return $bins }
    else { return $false }
}

function search_bucket($bucket, $query) {
    $apps = Get-ChildItem (Find-BucketDirectory $bucket) -Filter '*.json' -Recurse

    $apps | ForEach-Object {
        $filepath = $_.FullName

        $json = try {
            [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText($filepath))
        } catch {
            debug "Failed to parse manifest file: $filepath (error: $_)"
            return
        }

        $name = $_.BaseName

        if ($name -match $query) {
            $list.Add([PSCustomObject]@{
                    Name     = $name
                    Version  = $json.RootElement.GetProperty('version')
                    Source   = $bucket
                    Binaries = ''
                })
        } else {
            $bin = bin_match_json $json $query
            if ($bin) {
                $list.Add([PSCustomObject]@{
                        Name     = $name
                        Version  = $json.RootElement.GetProperty('version')
                        Source   = $bucket
                        Binaries = $bin -join ' | '
                    })
            }
        }
    }
}

# fallback function for PowerShell 5
function search_bucket_legacy($bucket, $query) {
    $apps = Get-ChildItem (Find-BucketDirectory $bucket) -Filter '*.json' -Recurse

    $apps | ForEach-Object {
        $manifest = [System.IO.File]::ReadAllText($_.FullName) | ConvertFrom-Json -ErrorAction Continue
        $name = $_.BaseName

        if ($name -match $query) {
            $list.Add([PSCustomObject]@{
                    Name     = $name
                    Version  = $manifest.Version
                    Source   = $bucket
                    Binaries = ''
                })
        } else {
            $bin = bin_match $manifest $query
            if ($bin) {
                $list.Add([PSCustomObject]@{
                        Name     = $name
                        Version  = $manifest.Version
                        Source   = $bucket
                        Binaries = $bin -join ' | '
                    })
            }
        }
    }
}

function search_remote($bucket, $query) {
    $uri = [System.Uri](known_bucket_repo $bucket)
    if ($uri.AbsolutePath -match '/([a-zA-Z0-9]*)/([a-zA-Z0-9-]*)(?:.git|/)?') {
        $user = $Matches[1]
        $repo_name = $Matches[2]
        $api_link = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        $result = download_json $api_link | Select-Object -ExpandProperty tree |
            Where-Object -Value "^bucket/(.*$query.*)\.json$" -Property Path -Match |
            ForEach-Object { $Matches[1] }
    }

    $result
}

function search_remotes($query) {
    $buckets = known_bucket_repos
    $names = $buckets | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty name

    $results = $names | Where-Object { !(Test-Path $(Find-BucketDirectory $_)) } | ForEach-Object {
        @{ 'bucket' = $_; 'results' = (search_remote $_ $query) }
    } | Where-Object { $_.results }

    if ($results.count -gt 0) {
        Write-Host "Results from other known buckets...`n(add them using 'scoop bucket add <bucket name>')"
    }

    $remote_list = @()
    $results | ForEach-Object {
        $bucket = $_.bucket
        $_.results | ForEach-Object {
            $item = [ordered]@{}
            $item.Name = $_
            $item.Source = $bucket
            $remote_list += [PSCustomObject]$item
        }
    }
    $remote_list
}

if (get_config USE_SQLITE_CACHE) {
    . "$PSScriptRoot\..\lib\database.ps1"
    Find-ScoopDBItem $query -From @('name', 'binary', 'shortcut') |
        Select-Object -Property name, version, bucket, binary |
        ForEach-Object {
            $list.Add([PSCustomObject]@{
                    Name     = $_.name
                    Version  = $_.version
                    Source   = $_.bucket
                    Binaries = $_.binary
                })
        }
} else {
    # Try search index cache first for literal queries (fast, substring matching).
    # Queries with regex metacharacters skip the cache and go straight to regex.
    $cacheWasFresh = $false
    if ($query -notmatch '[.+*?|\[\](){}^$\\]') {
        $cacheWasFresh = init_search_cache
        if ($cacheWasFresh) { search_by_index $query }
    }

    # Fall back to regex full-scan when cache produced no results
    if ($list.Count -eq 0) {
        try {
            $regex = New-Object Regex $query, 'IgnoreCase'
        } catch {
            abort "Invalid regular expression: $($_.Exception.InnerException.Message)"
        }

        $jsonTextAvailable = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Location) -eq 'System.Text.Json' }

        Get-LocalBucket | ForEach-Object {
            if ($jsonTextAvailable) {
                search_bucket $_ $regex
            } else {
                search_bucket_legacy $_ $regex
            }
        }

        # Build cache for next time only if it wasn't already fresh
        if (-not $cacheWasFresh) { build_search_cache }
    }
}

if ($list.Count -gt 0) {
    Write-Host 'Results from local buckets...'
    $list
}

if ($list.Count -eq 0 -and !(github_ratelimit_reached)) {
    $remote_results = search_remotes $query
    if (!$remote_results) {
        warn 'No matches found.'
        exit 1
    }
    $remote_results
}

exit 0
