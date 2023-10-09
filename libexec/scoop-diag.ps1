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
        $Redacted,
        [Switch]
        $Color
    )

    if ([String]::IsNullOrEmpty($Value)) {
        return
    }

    $Red = "`e[31m"
    $Green = "`e[32m"
    $Yellow = "`e[33m"
    $Cyan = "`e[36m"
    $End = "`e[0m"
    if (!$Color) {
        $Red, $Green, $Yellow, $Cyan, $End = '', '', '', '', ''
    }

    if ($Redacted) {
        $Value = "$Red<redacted>$End"
    }

    $Value = "$Value".Replace($env:USERPROFILE, "$Green`$env:USERPROFILE$End")
    $Value = "$Value".Replace($env:USERNAME, "$Green<username>$End")

    $Name = $Name.PadRight(12, ' ')

    if ($Value -eq $True) {
        $Value = "$Green$Value$End"
    } elseif ($Value -eq $False) {
        $Value = "$Yellow$Value$End"
    }
    Write-Output "$Cyan$Name$End = $Value"
}

function Show-Header {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Value,
        [Switch]
        $Color
    )

    if ($Color) {
        Write-Output "`e[35m[$Value]`e[0m"
    } else {
        Write-Output "[$Value]"
    }
}

function Get-ParentProcess {
    $parent = [System.Diagnostics.Process]::GetCurrentProcess()
    while ($parent.MainModule.ModuleName -ieq 'pwsh.exe' -or $parent.MainModule.ModuleName -ieq 'powershell.exe') {
        $parent = $parent.Parent
    }
    return $parent.MainModule.ModuleName
}

function Show-Diag {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Switch]
        $Markdown,
        [Switch]
        $Color
    )

    $redactedConfigValues = @(
        'virustotal_api_key'
        'private_hosts'
        'gh_token'
        'proxy'
        'analytics_id'
        'alias'
    )

    if ($Markdown) {
        Write-Output "`n"
        Write-Output '```ini'
    }

    Show-Header -Color:$Color -Value 'PowerShell'
    Show-Value -Color:$Color -Name 'Path' -Value ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    Show-Value -Color:$Color -Name 'Version' -Value $PSversionTable.PSVersion.ToString()
    Show-Value -Color:$Color -Name 'Edition' -Value $PSversionTable.PSEdition
    Show-Value -Color:$Color -Name 'Architecture' -Value (Get-DefaultArchitecture)
    Show-Value -Color:$Color -Name 'RunAsAdmin' -Value (is_admin)
    $parent = Get-ParentProcess
    Show-Value -Color:$Color -Name 'Parent' -Value $parent

    Show-Header -Color:$Color -Value 'Helpers'
    Show-Value -Color:$Color -Name 'GitPath' -Value (Get-HelperPath -Helper Git)
    Show-Value -Color:$Color -Name 'GitVersion' -Value (Invoke-Git -Path $PSScriptRoot -ArgumentList 'version')
    Show-Value -Color:$Color -Name 'Zip' -Value (Test-HelperInstalled -Helper '7zip')
    Show-Value -Color:$Color -Name 'Lessmsi' -Value (Test-HelperInstalled -Helper 'Lessmsi')
    Show-Value -Color:$Color -Name 'Innounp' -Value (Test-HelperInstalled -Helper 'Innounp')
    Show-Value -Color:$Color -Name 'Dark' -Value (Test-HelperInstalled -Helper 'Dark')
    Show-Value -Color:$Color -Name 'Aria2' -Value (Test-HelperInstalled -Helper 'Aria2')
    Show-Value -Color:$Color -Name 'Zstd' -Value (Test-HelperInstalled -Helper 'Zstd')

    Show-Header -Color:$Color -Value 'Environment'
    Show-Value -Color:$Color -Name 'SCOOP' -Value $env:SCOOP
    Show-Value -Color:$Color -Name 'SCOOP_GLOBAL' -Value $env:SCOOP_GLOBAL
    Show-Value -Color:$Color -Name 'SCOOP_CACHE' -Value $env:SCOOP_CACHE
    Show-Value -Color:$Color -Name 'HTTPS_PROXY' -Value $env:HTTPS_PROXY -Redacted
    Show-Value -Color:$Color -Name 'HTTP_PROXY' -Value $env:HTTP_PROXY -Redacted

    Show-Header -Color:$Color -Value 'Scoop'
    Show-Value -Color:$Color -Name 'Outdated' -Value (is_scoop_outdated)
    Show-Value -Color:$Color -Name 'OnHold' -Value (Test-ScoopCoreOnHold)
    Show-Value -Color:$Color -Name 'Config' -Value $configFile
    Show-Value -Color:$Color -Name 'CoreRoot' -Value $coreRoot
    Show-Value -Color:$Color -Name 'ScoopDir' -Value $scoopdir
    Show-Value -Color:$Color -Name 'CacheDir' -Value $cachedir
    Show-Value -Color:$Color -Name 'GlobalDir' -Value $globaldir

    Show-Header -Color:$Color -Value 'Config'
    $scoopConfig.PSObject.Properties | ForEach-Object {
        Show-Value -Color:$Color -Name $_.Name -Value $_.Value -Redacted:($redactedConfigValues.Contains($_.Name))
    }

    if ($Markdown) {
        Write-Output '```'
        Write-Output "`n"
    }
}

Show-Diag -Markdown -Color

exit 0
