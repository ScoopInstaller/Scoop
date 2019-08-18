function Initialize-Variables {
    <#
    .SYNOPSIS
        Helper which needs to be executed in all other exposed helpers as it will provide all local variables to be used.
        Script bounded variables will be created and set.
    #>
    # Do not create variable when there are already defined.
    if (-not $dir) {
        $script:dir = $env:I_Dir
        $script:persist_dir = $env:I_PersistDir
        $script:fname = $env:I_Fname
    }
}

function Remove-RegisteredVariable {
    <#
    .SYNOPSIS
        Remove registered helper environment variables to prevent leakage into main powershell process.
    #>

    Get-ChildItem env: | Where-Object { $_.Name -like 'I_*' } | ForEach-Object { Remove-Item env:\$($_.Name) -Force }
}

function Test-Persistence {
    <#
    .SYNOPSIS
        Persistence check helper.
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

    Initialize-Variables

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
                $path = (Join-Path $dir $f)

                New-Item -Path $path -Force | Out-Null
                Set-Content -LiteralPath $path -Value $cont -Encoding ASCII
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]] $Item
    )
    Initialize-Variables

    foreach ($it in $Item) { Get-ChildItem $dir $it | Remove-Item -Force -Recurse }
}

Export-ModuleMember -Function Test-Persistence, Remove-AppDirItem, Remove-RegisteredVariable
