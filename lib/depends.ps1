# resolve dependencies for the supplied apps, and sort into the correct order
function install_order($apps, $arch) {
    $res = @()
    foreach ($app in $apps) {
        foreach ($dep in deps $app $arch) {
            if ($res -notcontains $dep) { $res += $dep }
        }
        if ($res -notcontains $app) { $res += $app }
    }
    return $res
}

# http://www.electricmonk.nl/docs/dependency_resolving_algorithm/dependency_resolving_algorithm.html
function deps($app, $arch) {
    $resolved = New-Object collections.arraylist
    dep_resolve $app $arch $resolved @()

    if ($resolved.count -eq 1) { return @() } # no dependencies
    return $resolved[0..($resolved.count - 2)]
}

function dep_resolve($app, $arch, $resolved, $unresolved) {
    $app, $bucket, $null = parse_app $app
    $unresolved += $app
    $null, $manifest, $null, $null = Find-Manifest $app $bucket

    if (!$manifest) {
        if (((Get-LocalBucket) -notcontains $bucket) -and $bucket) {
            warn "Bucket '$bucket' not installed. Add it with 'scoop bucket add $bucket' or 'scoop bucket add $bucket <repo>'."
        }
        abort "Couldn't find manifest for '$app'$(if(!$bucket) { '.' } else { " from '$bucket' bucket." })"
    }

    $deps = @(Get-InstallationHelper $manifest $arch) + @(runtime_deps $manifest) | Select-Object -Unique

    foreach ($dep in $deps) {
        if ($resolved -notcontains $dep) {
            if ($unresolved -contains $dep) {
                abort "Circular dependency detected: '$app' -> '$dep'."
            }
            dep_resolve $dep $arch $resolved $unresolved
        }
    }
    $resolved.add($app) | Out-Null
    $unresolved = $unresolved -ne $app # remove from unresolved
}

function runtime_deps($manifest) {
    if ($manifest.depends) { return $manifest.depends }
}
function Get-InstallationHelper {
    <#
    .SYNOPSIS
        Get helpers that used in installation
    .PARAMETER Manifest
        App's manifest
    .PARAMETER Architecture
        Architecture of the app
    .PARAMETER All
        If true, return all helpers, otherwise return only helpers that are not already installed
    .OUTPUTS
        [Object[]]
        List of helpers
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [PSObject]
        $Manifest,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $Architecture,
        [Switch]
        $All
    )
    begin {
        $helper = @()
    }
    process {
        $url = arch_specific 'url' $Manifest $Architecture
        if (!$url) {
            $url = ''
        }
        $pre_install = arch_specific 'pre_install' $Manifest $Architecture
        $installer = arch_specific 'installer' $Manifest $Architecture
        $post_install = arch_specific 'post_install' $Manifest $Architecture
        $script = $pre_install + $installer.script + $post_install
        if (!$script) {
            $script = ''
        }
        if (((Test-7zipRequirement -Uri $url) -or ($script -like '*Expand-7zipArchive *')) -and !(get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
            $helper += '7zip'
        }
        if (((Test-LessmsiRequirement -Uri $url) -or ($script -like '*Expand-MsiArchive *')) -and (get_config MSIEXTRACT_USE_LESSMSI)) {
            $helper += 'lessmsi'
        }
        if ($Manifest.innosetup -or ($script -like '*Expand-InnoArchive *')) {
            $helper += 'innounp'
        }
        if ($script -like '*Expand-DarkArchive *') {
            $helper += 'dark'
        }
        if ((Test-ZstdRequirement -Uri $url) -or ($script -like '*Expand-ZstdArchive *')) {
            $helper += 'zstd'
        }
        if (!$All) {
            '7zip', 'lessmsi', 'innounp', 'dark', 'zstd' | ForEach-Object {
                if (Test-HelperInstalled -Helper $_) {
                    $helper = $helper -ne $_
                }
            }
        }
    }
    end {
        return $helper
    }
}

function Test-7zipRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Uri
    )
    return ($Uri | Where-Object {
            $_ -match '\.((gz)|(tar)|(t[abgpx]z2?)|(lzma)|(bz2?)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))(\.[^.]+)?$'
        }).Count -gt 0
}

function Test-ZstdRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Uri
    )
    return ($Uri | Where-Object { $_ -match '\.zst$' }).Count -gt 0
}

function Test-LessmsiRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $Uri
    )
    return ($Uri | Where-Object { $_ -match '\.msi$' }).Count -gt 0
}
