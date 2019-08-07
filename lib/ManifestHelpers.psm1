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
    param(
        [CmdletBinding(DefaultParameterSetName = 'Content')]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]] $File,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object[]] $Content,
        [ScriptBlock] $Execution
    )

    for ($ind = 0; $ind -lt $File.Count; ++$ind) {
        $f = $File[$ind]
        $cont = if ($Content.Count -lt $ind) { $Content[$ind] } else { $null } # $null when there is none specified on this index
        # PWSH has UTF-8 without BOM while, <=5 is using UTF-8 with bom
        $enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'UTF-8' } else { 'ASCII' }

        if (-not (Test-Path (Join-Path $persist_dir $f))) {
            if ($Execution) {
                & $Execution
            } else {
                Set-Content -LiteralPath (Join-Path $dir $f) -Value $cont -Encoding $enc -Force | Out-Null
            }
        }
    }
}

Export-ModuleMember -Function Test-Persistence
