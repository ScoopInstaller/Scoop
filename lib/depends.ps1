function Get-Dependency {
    <#
    .SYNOPSIS
        Get app's dependencies (with apps attached at the end).
    .PARAMETER AppName
        App's name
    .PARAMETER Architecture
        App's architecture
    .PARAMETER Resolved
        List of resolved dependencies (internal use)
    .PARAMETER Unresolved
        List of unresolved dependencies (internal use)
    .OUTPUTS
        [Object[]]
        List of app's dependencies
    .NOTES
        When pipeline input is used, the output will have duplicate items, and should be filtered by 'Select-Object -Unique'.
        ALgorithm: http://www.electricmonk.nl/docs/dependency_resolving_algorithm/dependency_resolving_algorithm.html
    #>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [PSObject]
        $AppName,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $Architecture,
        [String[]]
        $Resolved = @(),
        [String[]]
        $Unresolved = @()
    )
    process {
        $AppName, $manifest, $bucket, $null = Get-Manifest $AppName
        $Unresolved += $AppName

        if (!$manifest) {
            if (((Get-LocalBucket) -notcontains $bucket) -and $bucket) {
                warn "Bucket '$bucket' not installed. Add it with 'scoop bucket add $bucket' or 'scoop bucket add $bucket <repo>'."
            }
            abort "Couldn't find manifest for '$AppName'$(if(!$bucket) { '.' } else { " from '$bucket' bucket." })"
        }

        $deps = @(Get-InstallationHelper $manifest $Architecture) + @($manifest.depends) | Select-Object -Unique

        foreach ($dep in $deps) {
            if ($Resolved -notcontains $dep) {
                if ($Unresolved -contains $dep) {
                    abort "Circular dependency detected: '$AppName' -> '$dep'."
                }
                $Resolved, $Unresolved = Get-Dependency $dep $Architecture -Resolved $Resolved -Unresolved $Unresolved
            }
        }

        $Unresolved = $Unresolved -ne $AppName
        if ($bucket) {
            $Resolved += "$bucket/$AppName"
        } else {
            $Resolved += $AppName
        }
        if ($Unresolved.Length -eq 0) {
            return $Resolved
        } else {
            return $Resolved, $Unresolved
        }
    }
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
        $pre_install = arch_specific 'pre_install' $Manifest $Architecture
        $installer = arch_specific 'installer' $Manifest $Architecture
        $post_install = arch_specific 'post_install' $Manifest $Architecture
        $script = $pre_install + $installer.script + $post_install
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
        [AllowNull()]
        [String[]]
        $Uri
    )
    return ($Uri | Where-Object {
            $_ -match '\.((gz)|(tar)|(t[abgpx]z2?)|(lzma)|(bz2?)|(7z)|(001)|(rar)|(iso)|(xz)|(lzh)|(nupkg))(\.[^\d.]+)?$'
        }).Count -gt 0
}

function Test-ZstdRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
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
        [AllowNull()]
        [String[]]
        $Uri
    )
    return ($Uri | Where-Object { $_ -match '\.msi$' }).Count -gt 0
}
