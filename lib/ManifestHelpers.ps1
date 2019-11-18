function Test-Persistence {
    <#
    .SYNOPSIS
        Persistence check helper for files.
    .DESCRIPTION
        This will save some lines to not always write `if (-not (Test-Path $persist_dir\$file)) { New-item | Out-Null }` inside manifests.
    .PARAMETER File
        File to be checked.
    .PARAMETER Content
        If file does not exists it will be created with this value. Value should be array of strings or string.
    .PARAMETER Execution
        Custom scriptblock to run when file is not persisted.
        https://github.com/lukesampson/scoop-extras/blob/a84b257fd9636d02295b48c3fd32826487ca9bd3/bucket/ditto.json#L25-L33
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]] $File,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object[]] $Content,
        [ScriptBlock] $Execution
    )

    process {
        for ($ind = 0; $ind -lt $File.Count; ++$ind) {
            $currentFile = $File[$ind]

            if (-not (Join-Path $persist_dir $currentFile | Test-Path -Type Leaf)) {
                if (-not $quiet) { warn "File $currentFile do not exists. Creating." }

                if ($Execution) {
                    & $Execution
                } else {
                    # Handle edge case when there is only one file and mulitple contents caused by
                    # If `Test-Persistence alfa.txt @('new', 'beta')` is used,
                    # Powershell will bind Content as simple array with 2 values instead of Array with nested array with 2 values.
                    if (($File.Count -eq 1) -and ($Content.Count -gt 1)) {
                        $cont = $Content
                    } elseif ($ind -lt $Content.Count) {
                        $cont = $Content[$ind]
                    } else {
                        $cont = $null
                    }
                    $path = Join-Path $dir $currentFile

                    New-Item -Path $path -ItemType File -Force | Out-Null
                    if ($cont) { Set-Content -LiteralPath $path -Value $cont -Encoding Ascii }
                }
            }
        }
    }
}

function Remove-AppDirItem {
    <#
    .SYNOPSIS
        Remove given item from applications directory. Wildcards are supported.
    .PARAMETER Item
        Item to be removed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [String[]]
        $Item
    )

    process { foreach ($it in $Item) { Get-ChildItem $dir $it | Remove-Item -Force -Recurse } }
}

function New-JavaShortcutWrapper {
    <#
    .SYNOPSIS
        Create new shim-like batch file wrapper to spawn jar files within start menu (using shortcut).
    .PARAMETER Filename
        Filename of jar executable. Without .jar extension!
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String[]] $Filename)

    process {
        foreach ($f in $Filename) {
            Set-Content -LiteralPath (Join-Path $dir "$f.bat") -Value "@start javaw.exe -jar `"%~dp0$f.jar`" %*" -Encoding Ascii -Force
        }
    }
}

function Assert-Administrator {
    <#
    .SYNOPSIS
        Test if current user have administrator privileges needed for proper installation / uninstallation.
    #>
    if (-not (is_admin)) {
        error 'Administrator privileges are required for installation'
        # TODO:
        abort
    }
}

function Assert-WindowsVersion {
    <#
    .SYNOPSIS
        Test if Windows version meets application requirements.
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Version')]
        [String]
        $RequiredVersion
    )

    if ((Compare-Version ([System.Environment]::OSVersion.Version.ToString()) $RequiredVersion) -eq -1) {
        error "Application requires at least Windows version $RequiredVersion"
        # TODO:
        abort
    }
}

#region dotNet Framework
function Get-InstalledDotNetFrameworkVersion {
    <#
    .SYNOPSIS
        List all installed .NET Framework versions.
    .OUTPUTS
        Array of installed versions.
    #>
    [CmdletBinding()]
    [OutputType([String[]])]

    $base = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

    $versions = @()
    '2.0.50727', '3.0', '3.5', '4\Full' | ForEach-Object {
        $versions += Get-ItemProperty "$base\v$_" 'Version' | Select-Object -ExpandProperty 'Version'
    }

    return $versions
}

function Get-LatestDotNetFrameworkVersion {
    <#
    .SYNOPSIS
        Get highest/latest installed version of .NET Framework.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param() # For some reason there has to be empty param block

    return Get-InstalledDotNetFrameworkVersion | Sort-Object | Select-Object -Last 1
}

function Convert-DotNetFrameworkVersion {
    <#
    .SYNOPSIS
        Convert .NET Framework version into comparable release key.
        https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
    .PARAMETER Version
        Version of .NET Framework.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Version
    )

    $key = switch -Wildcard ($Version) {
        '4.5.1*' { 378675; break; }
        '4.5.2*' { 379893; break; }
        '4.5*' { 378389; break; }
        '4.6.1*' { 394254; break; }
        '4.6.2*' { 394802; break; }
        '4.6*' { 393295; break; }
        '4.7.1*' { 461308; break; }
        '4.7.2*' { 461808; break; }
        '4.7*' { 460798; break; }
        '4.8*' { 528040; break; }
        default { $null }
    }

    return $key
}

function Assert-DotNetFramework {
    <#
    .SYNOPSIS
        Test if required .NET Framework version is installed.
    .PARAMETER RequiredVersion
        Required version of .NET Framework.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Version')]
        [String]
        $RequiredVersion
    )

    $latest = Get-LatestDotNetFrameworkVersion | Convert-DotNetFrameworkVersion
    $required = Convert-DotNetFrameworkVersion $RequiredVersion

    if ($latest -lt $required) {
        error "Application requires at least .NET Framework $RequiredVersion"
        # TODO:
        abort
    }
}
#endregion dotNet Framework
