# Usage: scoop search <query>
# Summary: Search available apps
# Help: Searches for apps that are available to install.
#
# If used with [query], shows app names that match the query.
# Without [query], shows all the available apps.
# Options:
#   -v, --verbose   Show extended application info
#   -k, --known     Search also by all known buckets

param(
  [String]$query,
  [Switch]$verbose = $false,
  [Switch]$known = $false
)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"

reset_aliases

function bin_match($manifest, $query) {
    if(!$manifest.bin) { return $false }
    foreach($bin in $manifest.bin) {
        $exe, $alias, $args = $bin
        $fname = split-path $exe -leaf -ea stop

        if((strip_ext $fname) -match $query) { return $fname }
        if($alias -match $query) { return $alias }
    }
    $false
}

function search_bucket($bucket, $query) {
    $apps = apps_in_bucket (Find-BucketDirectory $bucket) | ForEach-Object {
        @{ name = $_ }
    }

    if($query) {
        try {
            $query = new-object regex $query, 'IgnoreCase'
        } catch {
            abort "Invalid regular expression: $($_.exception.innerexception.message)"
        }

        $apps = $apps | Where-Object {
            if($_.name -match $query) { return $true }
            $bin = bin_match (manifest $_.name $bucket) $query
            if($bin) {
                $_.bin = $bin; return $true;
            }
        }
    }
    $apps | ForEach-Object { $_.version = (latest_version $_.name $bucket); $_ }
}

function download_json($url) {
    $progressPreference = 'silentlycontinue'
    $result = invoke-webrequest $url -UseBasicParsing | Select-Object -exp content | convertfrom-json
    $progressPreference = 'continue'
    $result
}

function github_ratelimit_reached {
    $api_link = "https://api.github.com/rate_limit"
    (download_json $api_link).rate.remaining -eq 0
}

function search_remote($bucket, $query) {
    $repo = known_bucket_repo $bucket

    $uri = [system.uri]($repo)
    if ($uri.absolutepath -match '/([a-zA-Z0-9]*)/([a-zA-Z0-9-]*)(.git|/)?') {
        $user = $matches[1]
        $repo_name = $matches[2]
        $api_link = "https://api.github.com/repos/$user/$repo_name/git/trees/HEAD?recursive=1"
        $result = download_json $api_link | Select-Object -exp tree | Where-Object {
            $_.path -match "(^(.*$query.*).json$)"
        } | ForEach-Object { $matches[2] }
    }

    $result
}

function search_remotes($query) {
    $buckets = known_bucket_repos
    $names = $buckets | get-member -m noteproperty | Select-Object -exp name

    $results = $names | Where-Object { !(test-path $(Find-BucketDirectory $_)) } | ForEach-Object {
        @{"bucket" = $_; "results" = (search_remote $_ $query)}
    } | Where-Object { $_.results }

    if ($results.count -gt 0) {
        "Results from other known buckets..."
        "(add them using 'scoop bucket add <name>')"
        ""
    }

    $results | ForEach-Object {
        "'$($_.bucket)' bucket:"
        $_.results | ForEach-Object { "    $_" }
        ""
    }
}

Get-LocalBucket | ForEach-Object {
    $res = search_bucket $_ $query
    $local_results = $local_results -or $res
    if($res) {
        $name = "$_"

        Write-Host "'$name' bucket:"
        $res | ForEach-Object {
            $item = "    $($_.name) ($($_.version))"
            if($_.bin) { $item += " --> includes '$($_.bin)'" }
            $item
            if($verbose) {
                $app, $bucket, $null = parse_app $_.name
                $status = app_status $app $global
                $manifest, $bucket = find_manifest $app $bucket
                if ($manifest) {
                    $install = install_info $app $status.version $global
                    $version_output = $manifest.version
                    if (!$manifest_file) {
                        $manifest_file = manifest_path $app $bucket
                    }

                    $dir = versiondir $app 'current' $global
                    $original_dir = versiondir $app $manifest.version $global
                    $persist_dir = persistdir $app $global

                    if($status.installed) {
                        $manifest_file = manifest_path $app $install.bucket
                        if ($install.url) {
                            $manifest_file = $install.url
                        }
                        if($status.version -eq $manifest.version) {
                            $version_output = $status.version
                        } else {
                            $version_output = "        $($status.version) (Update to $($manifest.version) available)"
                        }
                    }

                    Write-Output "        Name: $app"
                    if ($manifest.description) {
                        Write-Output "        Description: $($manifest.description)"
                    }
                    Write-Output "        Version: $version_output"
                    Write-Output "        Website: $($manifest.homepage)"
                    # Show license
                    if ($manifest.license) {
                        $license = $manifest.license
                        if ($manifest.license.identifier -and $manifest.license.url) {
                            $license = "$($manifest.license.identifier) ($($manifest.license.url))"
                        } elseif ($manifest.license -match '^((ht)|f)tps?://') {
                            $license = "$($manifest.license)"
                        } elseif ($manifest.license -match '[|,]') {
                            $licurl = $manifest.license.Split("|,") | ForEach-Object {"https://spdx.org/licenses/$_.html"}
                            $license = "$($manifest.license) ($($licurl -join ', '))"
                        } else {
                            $license = "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)"
                        }
                        Write-Output "        License: $license"
                    }

                    # Manifest file
                    Write-Output "        Manifest:`n          $manifest_file"

                    if($status.installed) {
                        # Show installed versions
                        Write-Output "        Installed:"
                        $versions = versions $app $global
                        $versions | ForEach-Object {
                            $dir = versiondir $app $_ $global
                            if($global) { $dir += " *global*" }
                            Write-Output "          $dir"
                        }
                    } else {
                        Write-Output "        Installed: No"
                    }

                    $binaries = @(arch_specific 'bin' $manifest $install.architecture)
                    if($binaries) {
                        $binary_output = "Binaries:`n         "
                        $binaries | ForEach-Object {
                            if($_ -is [System.Array]) {
                                $binary_output += " $($_[1]).exe"
                            } else {
                                $binary_output += " $_"
                            }
                        }
                        Write-Output "        $binary_output"
                    }

                    if($manifest.env_set -or $manifest.env_add_path) {
                        if($status.installed) {
                            Write-Output "        Environment:"
                        } else {
                            Write-Output "        Environment: (simulated)"
                        }
                    }
                    if($manifest.env_set) {
                        $manifest.env_set | Get-Member -member noteproperty | ForEach-Object {
                            $value = env $_.name $global
                            if(!$value) {
                                $value = format $manifest.env_set.$($_.name) @{ "dir" = $dir }
                            }
                            Write-Output "          $($_.name)=$value"
                        }
                    }
                    if($manifest.env_add_path) {
                        $manifest.env_add_path | Where-Object { $_ } | ForEach-Object {
                            if($_ -eq '.') {
                                Write-Output "          PATH=%PATH%;$dir"
                            } else {
                                Write-Output "          PATH=%PATH%;$dir\$_"
                            }
                        }
                    }

                    # Show notes
                    show_notes $manifest $dir $original_dir $persist_dir
                }
            }
        }
        ""
    }
}

if (!(github_ratelimit_reached) -and (!$local_results -or $known)) {
    $remote_results = search_remotes $query
    if(!$remote_results) { [console]::error.writeline("No matches found."); exit 1 }
    $remote_results
}

exit 0
