function Get-VaribleFromSessionState {
    <#
    .SYNOPSIS
        Helper to get content of variable from session state.
    .PARAMETER Name
        Name of variable to be resolved.
    #>
    param([String] $Name)

    return $PSCmdlet.SessionState.PSVariable.GetValue($Name)
}

function Initialize-Variable {
    <#
    .SYNOPSIS
        Helper which needs to be executed in all other exposed helpers as it will provide all local variables to be used.
        Script bounded variables will be created and set.
    #>

    # Do not create variable when there are already defined.
    if (-not $dir) {
        'dir', 'persist_dir', 'fname', 'version', 'global', 'manifest' | ForEach-Object {
            Get-VaribleFromSessionState $_ | New-Variable -Name $_ -Scope Script
        }
    }
}

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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]] $File,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object[]] $Content,
        [ScriptBlock] $Execution
    )

    Initialize-Variable

    for ($ind = 0; $ind -lt $File.Count; ++$ind) {
        $f = $File[$ind]

        if (-not (Test-Path (Join-Path $persist_dir $f))) {
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
                $path = Join-Path $dir $f

                New-Item -Path $path -ItemType File -Force | Out-Null
                if ($cont) { Set-Content -LiteralPath $path -Value $cont -Encoding Ascii }
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
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String[]] $Item)

    Initialize-Variable

    foreach ($it in $Item) { Get-ChildItem $dir $it | Remove-Item -Force -Recurse }
}

function New-JavaShortcutWrapper {
    <#
    .SYNOPSIS
        Create new shim-like batch file wrapper to spawn jar files within start menu (shortcut).
    .PARAMETER Filename
        Filename of jar executable. Without .jar extension!
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String[]] $Filename)

    Initialize-Variable

    foreach ($f in $Filename) {
        Set-Content -LiteralPath (Join-Path $dir "$f.bat") -Value "@start javaw.exe -jar `"%~dp0$f.jar`" %*" -Encoding Ascii -Force
    }
}

Export-ModuleMember -Function Test-Persistence, Remove-AppDirItem, New-JavaShortcutWrapper
