<#
Diagnostic tests.
Return $true if the test passed, otherwise $false.
Use 'warn' to highlight the issue, and follow up with the recommended actions to rectify.
#>
function check_windows_defender($global) {
    $defender = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if (Test-CommandAvailable Get-MpPreference) {
        if ((Get-MpPreference).DisableRealtimeMonitoring) { return $true }
        if ($defender -and $defender.Status) {
            if ($defender.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                $installPath = $scoopdir;
                if ($global) { $installPath = $globaldir; }

                $exclusionPath = (Get-MpPreference).ExclusionPath
                if (!($exclusionPath -contains $installPath)) {
                    info "Windows Defender may slow down or disrupt installs with realtime scanning."
                    Write-Host "  Consider running:"
                    Write-Host "    sudo Add-MpPreference -ExclusionPath '$installPath'"
                    Write-Host "  (Requires 'sudo' command. Run 'scoop install sudo' if you don't have it.)"
                    return $false
                }
            }
        }
    }
    return $true
}

function check_main_bucket {
    if ((Get-LocalBucket) -notcontains 'main') {
        warn 'Main bucket is not added.'
        Write-Host "  run 'scoop bucket add main'"

        return $false
    }

    return $true
}

function check_long_paths {
    if ([System.Environment]::OSVersion.Version.Major -lt 10 -or [System.Environment]::OSVersion.Version.Build -lt 1607) {
        warn 'This version of Windows does not support configuration of LongPaths.'
        return $false
    }
    $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction SilentlyContinue -Name 'LongPathsEnabled'
    if (!$key -or ($key.LongPathsEnabled -eq 0)) {
        warn 'LongPaths support is not enabled.'
        Write-Host "  You can enable it by running:"
        Write-Host "    sudo Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1"
        Write-Host "  (Requires 'sudo' command. Run 'scoop install sudo' if you don't have it.)"
        return $false
    }

    return $true
}

function Get-WindowsDeveloperModeStatus {
    $DevModRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (!(Test-Path -Path $DevModRegistryPath) -or (Get-ItemProperty -Path `
        $DevModRegistryPath -Name AllowDevelopmentWithoutDevLicense -ErrorAction `
        SilentlyContinue).AllowDevelopmentWithoutDevLicense -ne 1) {
        warn "Windows Developer Mode is not enabled. Operations relevant to symlinks may fail without proper rights."
        Write-Host "  You may read more about the symlinks support here:"
        Write-Host "  https://blogs.windows.com/windowsdeveloper/2016/12/02/symlinks-windows-10/"
        return $false
    }

    return $true
}


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
        $Color,
        [Int]
        $PadRight = 12
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

    $Name = $Name.PadRight($PadRight, ' ')

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
    Show-Value -Color:$Color -Name 'RunAsAdmin' -Value (Test-IsAdmin)
    Show-Value -Color:$Color -Name 'Parent' -Value (Get-ParentProcess)

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
    $pad = ($scoopConfig.PSObject.Properties.Name | Measure-Object -Maximum -Property Length).Maximum
    $scoopConfig.PSObject.Properties | ForEach-Object {
        Show-Value -Color:$Color -Name $_.Name -Value $_.Value -PadRight $pad -Redacted:($redactedConfigValues.Contains($_.Name))
    }

    if ($Markdown) {
        Write-Output '```'
        Write-Output "`n"
    }
}
