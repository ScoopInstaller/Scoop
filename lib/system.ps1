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
        $envRegisterKey.DeleteValue($Name)
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

function search_in_path($target) {
    $path = (Get-EnvVar -Name 'PATH' -Global) + ';' + (Get-EnvVar -Name 'PATH')
    foreach ($dir in $path.split(';')) {
        if (Test-Path "$dir\$target" -PathType leaf) {
            return "$dir\$target"
        }
    }
}

function ensure_in_path($dir, $global) {
    $path = Get-EnvVar -Name 'PATH' -Global:$global
    $dir = fullpath $dir
    if ($path -notmatch [regex]::escape($dir)) {
        Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."
        Set-EnvVar -Name 'PATH' -Value "$dir;$path" -Global:$global # future sessions
        $env:PATH = "$dir;$env:PATH" # current session
    }
}

function strip_path($orig_path, $dir) {
    if ($null -eq $orig_path) { $orig_path = '' }
    $stripped = [string]::join(';', @( $orig_path.split(';') | Where-Object { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
}

function add_first_in_path($dir, $global) {
    $dir = fullpath $dir
    # future sessions
    $null, $currpath = strip_path (Get-EnvVar -Name 'PATH' -Global:$global) $dir
    Set-EnvVar -Name 'PATH' -Value "$dir;$currpath" -Global:$global
    # current session
    $null, $env:PATH = strip_path $env:PATH $dir
    $env:PATH = "$dir;$env:PATH"
}

function remove_from_path($dir, $global) {
    $dir = fullpath $dir
    # future sessions
    $was_in_path, $newpath = strip_path (Get-EnvVar -Name 'PATH' -Global:$global) $dir
    if ($was_in_path) {
        Write-Output "Removing $(friendly_path $dir) from your path."
        Set-EnvVar -Name 'PATH' -Value $newpath -Global:$global
    }
    # current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if ($was_in_path) {
        $env:PATH = $newpath
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
