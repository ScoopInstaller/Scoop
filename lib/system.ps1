# System-related functions

## Environment Variables

function Publish-EnvVar {
    if (-not ('Win32.NativeMethods' -as [Type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult
);
'@
    }

    $HWND_BROADCAST = [IntPtr] 0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [UIntPtr]::Zero

    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        'Environment',
        2,
        5000,
        [ref] $result
    ) | Out-Null
}

function Get-EnvVar {
    param(
        [string]$Name,
        [switch]$Global
    )

    $registerKey = if ($Global) {
        Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else {
        Get-Item -Path 'HKCU:'
    }
    $envRegisterKey = $registerKey.OpenSubKey('Environment')
    $registryValueOption = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
    $envRegisterKey.GetValue($Name, $null, $registryValueOption)
}

function Set-EnvVar {
    param(
        [string]$Name,
        [string]$Value,
        [switch]$Global
    )

    $registerKey = if ($Global) {
        Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else {
        Get-Item -Path 'HKCU:'
    }
    $envRegisterKey = $registerKey.OpenSubKey('Environment', $true)
    if ($null -eq $Value -or $Value -eq '') {
        if ($envRegisterKey.GetValue($Name)) {
            $envRegisterKey.DeleteValue($Name)
        }
    } else {
        $registryValueKind = if ($Value.Contains('%')) {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        } elseif ($envRegisterKey.GetValue($Name)) {
            $envRegisterKey.GetValueKind($Name)
        } else {
            [Microsoft.Win32.RegistryValueKind]::String
        }
        $envRegisterKey.SetValue($Name, $Value, $registryValueKind)
    }
    Publish-EnvVar
}

function Split-PathLikeEnvVar {
    param(
        [string[]]$Pattern,
        [string]$Path
    )

    if ($null -eq $Path -and $Path -eq '') {
        return $null, $null
    } else {
        $splitPattern = $Pattern.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
        $splitPath = $Path.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
        $inPath = @()
        foreach ($p in $splitPattern) {
            $inPath += $splitPath.Where({ $_ -like $p })
            $splitPath = $splitPath.Where({ $_ -notlike $p })
        }
        return ($inPath -join ';'), ($splitPath -join ';')
    }
}

function Add-Path {
    param(
        [string[]]$Path,
        [string]$TargetEnvVar = 'PATH',
        [switch]$Global,
        [switch]$Force,
        [switch]$Quiet
    )

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
    if (!$inPath -or $Force) {
        if (!$Quiet) {
            $Path | ForEach-Object {
                Write-Host "Adding $(friendly_path $_) to $(if ($Global) {'global'} else {'your'}) path."
            }
        }
        Set-EnvVar -Name $TargetEnvVar -Value ((@($Path) + $strippedPath) -join ';') -Global:$Global
    }
    # current session
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path $env:PATH
    if (!$inPath -or $Force) {
        $env:PATH = (@($Path) + $strippedPath) -join ';'
    }
}

function Remove-Path {
    param(
        [string[]]$Path,
        [string]$TargetEnvVar = 'PATH',
        [switch]$Global,
        [switch]$Quiet,
        [switch]$PassThru
    )

    # future sessions
    $inPath, $strippedPath = Split-PathLikeEnvVar $Path (Get-EnvVar -Name $TargetEnvVar -Global:$Global)
    if ($inPath) {
        if (!$Quiet) {
            $Path | ForEach-Object {
                Write-Host "Removing $(friendly_path $_) from $(if ($Global) {'global'} else {'your'}) path."
            }
        }
        Set-EnvVar -Name $TargetEnvVar -Value $strippedPath -Global:$Global
    }
    # current session
    $inSessionPath, $strippedPath = Split-PathLikeEnvVar $Path $env:PATH
    if ($inSessionPath) {
        $env:PATH = $strippedPath
    }
    if ($PassThru) {
        return $inPath
    }
}

## Deprecated functions

function env($name, $global, $val) {
    if ($PSBoundParameters.ContainsKey('val')) {
        Show-DeprecatedWarning $MyInvocation 'Set-EnvVar'
        Set-EnvVar -Name $name -Value $val -Global:$global
    } else {
        Show-DeprecatedWarning $MyInvocation 'Get-EnvVar'
        Get-EnvVar -Name $name -Global:$global
    }
}

function strip_path($orig_path, $dir) {
    Show-DeprecatedWarning $MyInvocation 'Split-PathLikeEnvVar'
    Split-PathLikeEnvVar -Pattern @($dir) -Path $orig_path
}

function add_first_in_path($dir, $global) {
    Show-DeprecatedWarning $MyInvocation 'Add-Path'
    Add-Path -Path $dir -Global:$global -Force
}

function remove_from_path($dir, $global) {
    Show-DeprecatedWarning $MyInvocation 'Remove-Path'
    Remove-Path -Path $dir -Global:$global
}
