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
        [Parameter(ParameterSetName = 'Content')]
		[Object[]] $Content,
        [Parameter(ParameterSetName = 'Execution')]
		[ScriptBlock] $Execution
	)

	for ($ind = 0; $ind -lt $File.Count; ++$ind) {
		$f = $File[$ind]
		$cont = $Content[$ind] # $null when there is none specified on this index
		# PWSH has UTF-8 without BOM while, <=5 is using UTF-8 with bom
		$enc = if ($PSVersionTable.PSVersion.Major -ge 6) { 'UTF-8' } else { 'ASCII' }

		if (-not (Test-Path (Join-Path $persist_dir $f))) {
			if ($Execution) {
				& $Execution
			} else {
				Set-Content (Join-Path $dir $f) -ItemType File -Value $cont -Encoding $enc | Out-Null
				New-Item -Path $dir -Name $f -ItemType File -Value $cont | Out-Null
			}
		}
	}
}

Export-ModuleMember -Function Test-Persistence
