# Usage: scoop info <app> [--verbose]
# Summary: Display information about an app
# Options:
#   -v, --verbose       Show full paths and URLs

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest'
. "$PSScriptRoot\..\lib\versions.ps1" # 'Get-InstalledVersion'

$opt, $app, $err = getopt $args 'v' 'verbose'
if ($err) { error "scoop info: $err"; exit 1 }
$verbose = $opt.v -or $opt.verbose

if (!$app) { my_usage; exit 1 }

$app, $manifest, $bucket, $url = Get-Manifest $app

if (!$manifest) {
    abort "Could not find manifest for '$(show_app $app)' in local buckets."
}

$global = installed $app $true
$status = app_status $app $global
$install = install_info $app $status.version $global
$status.installed = $bucket -and $install.bucket -eq $bucket
$version_output = $manifest.version
$manifest_file = if ($bucket) {
    manifest_path $app $bucket
} else {
    $url
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
