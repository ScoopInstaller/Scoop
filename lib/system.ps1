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

function Test-PathLikeEnvVar {
    param(
        [string]$Name,
        [string]$Path
    )

    if ($null -eq $Path -and $Path -eq '') {
        return $false, $null
    } else {
        $strippedPath = $Path.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries).Where({ $_ -ne $Name }) -join ';'
        return ($strippedPath -ne $Path), $strippedPath
    }
}

function Add-Path {
    param(
        [string]$Path,
        [switch]$Global,
        [switch]$Force
    )

    if (!$Path.Contains('%')) {
        $Path = Get-AbsolutePath $Path
    }
    # future sessions
    $inPath, $strippedPath = Test-PathLikeEnvVar $Path (Get-EnvVar -Name 'PATH' -Global:$Global)
    if (!$inPath -or $Force) {
        Write-Output "Adding $(friendly_path $Path) to $(if ($Global) {'global'} else {'your'}) path."
        Set-EnvVar -Name 'PATH' -Value (@($Path, $strippedPath) -join ';') -Global:$Global
    }
    # current session
    $inPath, $strippedPath = Test-PathLikeEnvVar $Path $env:PATH
    if (!$inPath -or $Force) {
        $env:PATH = @($Path, $strippedPath) -join ';'
    }
}

function Remove-Path {
    param(
        [string]$Path,
        [switch]$Global
    )

    if (!$Path.Contains('%')) {
        $Path = Get-AbsolutePath $Path
    }
    # future sessions
    $inPath, $strippedPath = Test-PathLikeEnvVar $Path (Get-EnvVar -Name 'PATH' -Global:$Global)
    if ($inPath) {
        Write-Output "Removing $(friendly_path $Path) from $(if ($Global) {'global'} else {'your'}) path."
        Set-EnvVar -Name 'PATH' -Value $strippedPath -Global:$Global
    }
    # current session
    $inPath, $strippedPath = Test-PathLikeEnvVar $Path $env:PATH
    if ($inPath) {
        $env:PATH = $strippedPath
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
    Show-DeprecatedWarning $MyInvocation 'Test-PathLikeEnvVar'
    Test-PathLikeEnvVar -Name $dir -Path $orig_path
}

function add_first_in_path($dir, $global) {
    Show-DeprecatedWarning $MyInvocation 'Add-Path'
    Add-Path -Path $dir -Global:$global -Force
}

function remove_from_path($dir, $global) {
    Show-DeprecatedWarning $MyInvocation 'Remove-Path'
    Remove-Path -Path $dir -Global:$global
}
