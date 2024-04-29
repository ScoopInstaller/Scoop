# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
#   - With 'use_sqlite_cache' enabled, [query] is partially matched against app names, binaries, and shortcuts.
#   - Without 'use_sqlite_cache', [query] can be a regular expression to match against app names and binaries.
# Without [query], shows all the available apps.
param($query)

. "$PSScriptRoot\..\lib\manifest.ps1" # 'manifest'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-LatestVersion'
. "$PSScriptRoot\..\lib\download.ps1"

$list = [System.Collections.Generic.List[PSCustomObject]]::new()

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
        $result = Get-RemoteFile $api_link | ConvertFrom-Json | Select-Object -ExpandProperty tree |
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
        Write-Host "Results from other known buckets...
(add them using 'scoop bucket add <bucket name>')"
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
    Select-ScoopDBItem $query -From @('name', 'binary', 'shortcut') |
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
    try {
        $query = New-Object Regex $query, 'IgnoreCase'
    } catch {
        abort "Invalid regular expression: $($_.Exception.InnerException.Message)"
    }

    $jsonTextAvailable = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Location) -eq 'System.Text.Json' }

    Get-LocalBucket | ForEach-Object {
        if ($jsonTextAvailable) {
            search_bucket $_ $query
        } else {
            search_bucket_legacy $_ $query
        }
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
