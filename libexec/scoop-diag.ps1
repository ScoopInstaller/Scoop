# Usage: scoop diag
# Summary: Returns information about the Scoop environment that can be posted on a GitHub issue

function Show-Value {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        [String]
        $Value,
        [Switch]
        $Redacted
    )

    if([String]::IsNullOrEmpty($Value)) {
        return
    }

    if($Redacted) {
        $Value = '<redacted>'
    }

    $Value = "$Value".Replace($env:USERPROFILE, '%USERPROFILE%')
    $Value = "$Value".Replace($env:USERNAME, '<username>')

    $Name = $Name.PadRight(12, ' ')

    Write-Output "$Name = $Value"
}

$redactedConfigValues = @(
    'virustotal_api_key'
    'private_hosts'
    'gh_token'
    'proxy'
    'analytics_id'
    'alias'
)

Write-Output "`n"
Write-Output '```ini'

Write-Output "[PowerShell]"
Show-Value -Name 'Path' -Value ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
Show-Value -Name 'Version' -Value $PSversionTable.PSVersion.ToString()
Show-Value -Name 'Edition' -Value $PSversionTable.PSEdition
Show-Value -Name 'Architecture' -Value (Get-DefaultArchitecture)
Show-Value -Name 'RunAsAdmin' -Value (is_admin)

Write-Output "[Helpers]"
Show-Value -Name 'GitPath' -Value (Get-HelperPath -Helper Git)
Show-Value -Name 'GitVersion' -Value (Invoke-Git -Path $PSScriptRoot -ArgumentList 'version')
Show-Value -Name 'Zip' -Value (Test-HelperInstalled -Helper '7zip')
Show-Value -Name 'Lessmsi' -Value (Test-HelperInstalled -Helper 'Lessmsi')
Show-Value -Name 'Innounp' -Value (Test-HelperInstalled -Helper 'Innounp')
Show-Value -Name 'Dark' -Value (Test-HelperInstalled -Helper 'Dark')
Show-Value -Name 'Aria2' -Value (Test-HelperInstalled -Helper 'Aria2')
Show-Value -Name 'Zstd' -Value (Test-HelperInstalled -Helper 'Zstd')

Write-Output "[Environment]"
Show-Value -Name 'SCOOP' -Value $env:SCOOP
Show-Value -Name 'SCOOP_GLOBAL' -Value $env:SCOOP_GLOBAL
Show-Value -Name 'SCOOP_CACHE' -Value $env:SCOOP_CACHE
Show-Value -Name 'HTTPS_PROXY' -Value $env:HTTPS_PROXY -Redacted
Show-Value -Name 'HTTP_PROXY' -Value $env:HTTP_PROXY -Redacted

Write-Output "[Scoop]"
Show-Value -Name 'Outdated' -Value (is_scoop_outdated)
Show-Value -Name 'OnHold' -Value (Test-ScoopCoreOnHold)
Show-Value -Name 'Config' -Value $configFile
Show-Value -Name 'CoreRoot' -Value $coreRoot
Show-Value -Name 'ScoopDir' -Value $scoopdir
Show-Value -Name 'CacheDir' -Value $cachedir
Show-Value -Name 'GlobalDir' -Value $globaldir

Write-Output "[Config]"
$scoopConfig.PSObject.Properties | ForEach-Object {
    Show-Value -Name $_.Name -Value $_.Value -Redacted:($redactedConfigValues.Contains($_.Name))
}

Write-Output '```'
Write-Output "`n"

exit 0
