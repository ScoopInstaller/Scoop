# Usage: scoop info <app> [--verbose]
# Summary: Display information about an app
# Options:
#   -v, --verbose       Show full paths and URLs

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Find-Manifest' (indirectly)
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-InstalledVersion'

$opt, $app, $err = getopt $args 'v' 'verbose'
if ($err) { error "scoop info: $err"; exit 1 }
$verbose = $opt.v -or $opt.verbose

if (!$app) { my_usage; exit 1 }

if ($app -match '^(ht|f)tps?://|\\\\') {
    # check if $app is a URL or UNC path
    $url = $app
    $app = appname_from_url $url
    $global = installed $app $true
    $status = app_status $app $global
    $manifest = url_manifest $url
    $manifest_file = $url
} else {
    # else $app is a normal app name
    $global = installed $app $true
    $app, $bucket, $null = parse_app $app
    $status = app_status $app $global
    $app, $manifest, $bucket, $url = Find-Manifest $app $bucket
}

if (!$manifest) {
    abort "Could not find manifest for '$(show_app $app $bucket)'."
}

$install = install_info $app $status.version $global
$status.installed = $bucket -and $install.bucket -eq $bucket
$version_output = $manifest.version
if (!$manifest_file) {
    $manifest_file = if ($bucket) { manifest_path $app $bucket } else { $url }
}

if ($verbose) {
    $dir = currentdir $app $global
    $original_dir = versiondir $app $manifest.version $global
    $persist_dir = persistdir $app $global
} else {
    $dir, $original_dir, $persist_dir = "<root>", "<root>", "<root>"
}

if ($status.installed) {
    $manifest_file = manifest_path $app $install.bucket
    if ($install.url) {
        $manifest_file = $install.url
    }
    if ($status.version -eq $manifest.version) {
        $version_output = $status.version
    } else {
        $version_output = "$($status.version) (Update to $($manifest.version) available)"
    }
}

$item = [ordered]@{ Name = $app }
if ($manifest.description) {
    $item.Description = $manifest.description
}
$item.Version = $version_output
if ($bucket) {
    $item.Bucket = $bucket
}
if ($manifest.homepage) {
    $item.Website = $manifest.homepage.TrimEnd('/')
}
# Show license
if ($manifest.license) {
    $item.License = if ($manifest.license.identifier -and $manifest.license.url) {
        if ($verbose) { "$($manifest.license.identifier) ($($manifest.license.url))" } else { $manifest.license.identifier }
    } elseif ($manifest.license -match '^((ht)|f)tps?://') {
        $manifest.license
    } elseif ($manifest.license -match '[|,]') {
        if ($verbose) {
            "$($manifest.license) ($(($manifest.license -Split "\||," | ForEach-Object { "https://spdx.org/licenses/$_.html" }) -join ', '))"
        } else {
            $manifest.license
        }
    } else {
        if ($verbose) { "$($manifest.license) (https://spdx.org/licenses/$($manifest.license).html)" } else { $manifest.license }
    }
}

if ($manifest.depends) {
    $item.Dependencies = $manifest.depends -join ' | '
}

if (Test-Path $manifest_file) {
    if (Get-Command git -ErrorAction Ignore) {
        $gitinfo = (git -C (Split-Path $manifest_file) log -1 -s --format='%aD#%an' $manifest_file 2> $null) -Split '#'
    }
    if ($gitinfo) {
        $item.'Updated at' = $gitinfo[0] | Get-Date
        $item.'Updated by' = $gitinfo[1]
    } else {
        $item.'Updated at' = (Get-Item $manifest_file).LastWriteTime
        $item.'Updated by' = (Get-Acl $manifest_file).Owner.Split('\')[-1]
    }
}

# Manifest file
if ($verbose) { $item.Manifest = $manifest_file }

if ($status.installed) {
    # Show installed versions
    $installed_output = @()
    Get-InstalledVersion -AppName $app -Global:$global | ForEach-Object {
        $installed_output += if ($verbose) { versiondir $app $_ $global } else { "$_$(if ($global) { " *global*" })" }
    }
    $item.Installed = $installed_output -join "`n"

    if ($verbose) {
        # Show size of installation
        $appsdir = appsdir $global

        $appFiles = Get-ChildItem $appsdir | Where-Object -Property Name -Value "^$app$" -Match
        $currentFiles = Get-ChildItem $appFiles | Where-Object -Property Name -Value (Select-CurrentVersion $app $global) -Match
        $persistFiles = Get-ChildItem $persist_dir -ErrorAction Ignore # Will fail if app does not persist data
        $cacheFiles = Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match

        $totalSize = 0
        $fileTotals = @()
        foreach ($fileType in ($appFiles, $persistFiles, $cacheFiles)) {
            if ($fileType.Length -ne 0) {
                $fileSum = (Get-ChildItem $fileType -Recurse | Measure-Object -Property Length -Sum).Sum
                $fileTotals += $fileSum
                $totalSize += $fileSum
            } else {
                $fileTotals += 0
            }
        }

        # Separate so that it doesn't double count in $totalSize
        $currentTotal = (Get-ChildItem $currentFiles -Recurse | Measure-Object -Property Length -Sum).Sum

        # Old versions = app total - current version size
        $fileTotals += $fileTotals[0] - $currentTotal

        $item.'Installed size' = "Current version:   $(filesize $currentTotal)`nOld versions:      $(filesize $fileTotals[3])`nPersisted data:    $(filesize $fileTotals[1])`nCached downloads:  $(filesize $fileTotals[2])`nTotal:             $(filesize $totalSize)"
    }
} else {
    if ($verbose) {
        # Get download size if app not installed
        $architecture = default_architecture

        if(!(supports_architecture $manifest $architecture)) {
        # No available download for current architecture
            continue
        }

        if ($null -eq $manifest.url) {
            # use url for current architecture
            $urls = url $manifest $architecture
        } else {
            # otherwise use non-architecture url
            $urls = $manifest.url
        }

        $totalPackage = 0
        foreach($url in $urls) {
            try {
                [int]$urlLength = (Invoke-WebRequest $url -Method Head).Headers.'Content-Length'[0]
                $totalPackage += $urlLength

                if (Test-Path (fullpath (cache_path $app $manifest.version $url))) {
                    $cached = " (latest version is cached)"
                } else {
                    $cached = $null
                }
            } catch [System.Management.Automation.RuntimeException] {
                $totalPackage = 0
                $packageError = "the server at $(([System.Uri]$url).Host) did not send a Content-Length header"
                break
            } catch {
                $totalPackage = 0
                $packageError = "the server at $(([System.Uri]$url).Host) is down"
                break
            }
        }
        if ($totalPackage -ne 0) {
            $item.'Download size' = "$(filesize $totalPackage)$cached"
        } else {
            $item.'Download size' = "Unknown ($packageError)"
        }
    }
}

$binaries = @(arch_specific 'bin' $manifest $install.architecture)
if ($binaries) {
    $binary_output = @()
    $binaries | ForEach-Object {
        if ($_ -is [System.Array]) {
            $binary_output += "$($_[1]).$($_[0].Split('.')[-1])"
        } else {
            $binary_output += $_
        }
    }
    $item.Binaries = $binary_output -join " | "
}
$shortcuts = @(arch_specific 'shortcuts' $manifest $install.architecture)
if ($shortcuts) {
    $shortcut_output = @()
    $shortcuts | ForEach-Object {
        $shortcut_output += $_[1]
    }
    $item.Shortcuts = $shortcut_output -join " | "
}
$env_set = arch_specific 'env_set' $manifest $install.architecture
if ($env_set) {
    $env_vars = @()
    $env_set | Get-Member -member noteproperty | ForEach-Object {
        $env_vars += "$($_.name) = $(format $env_set.$($_.name) @{ "dir" = $dir })"
    }
    $item.Environment = $env_vars -join "`n"
}
$env_add_path = arch_specific 'env_add_path' $manifest $install.architecture
if ($env_add_path) {
    $env_path = @()
    $env_add_path | Where-Object { $_ } | ForEach-Object {
        $env_path += if ($_ -eq '.') {
            $dir
        } else {
            "$dir\$_"
        }
    }
    $item.'Path Added' = $env_path -join "`n"
}

if ($manifest.suggest) {
    $suggest_output = @()
    $manifest.suggest.PSObject.Properties | ForEach-Object {
        $suggest_output += $_.Value -join ' | '
    }
    $item.Suggestions = $suggest_output -join ' | '
}

if ($manifest.notes) {
    # Show notes
    $item.Notes = (substitute $manifest.notes @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir }) -join "`n"
}

[PSCustomObject]$item

exit 0
