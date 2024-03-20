function Publish-Env {
    if (-not ('Win32.NativeMethods' -as [Type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }

    $HWND_BROADCAST = [IntPtr] 0xffff
    $WM_SETTINGCHANGE = 0x1a
    $result = [UIntPtr]::Zero

    [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        'Environment',
        2,
        5000,
        [ref] $result
    ) | Out-Null
}

function env($name, $global, $val = '__get') {
    $RegisterKey = if ($global) {
        Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    } else {
        Get-Item -Path 'HKCU:'
    }
    $EnvRegisterKey = $RegisterKey.OpenSubKey('Environment', $val -ne '__get')

    if ($val -eq '__get') {
        $RegistryValueOption = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
        $EnvRegisterKey.GetValue($name, $null, $RegistryValueOption)
    } elseif ($val -eq $null) {
        try { $EnvRegisterKey.DeleteValue($name) } catch { }
        Publish-Env
    } else {
        $RegistryValueKind = if ($val.Contains('%')) {
            [Microsoft.Win32.RegistryValueKind]::ExpandString
        } elseif ($EnvRegisterKey.GetValue($name)) {
            $EnvRegisterKey.GetValueKind($name)
        } else {
            [Microsoft.Win32.RegistryValueKind]::String
        }
        $EnvRegisterKey.SetValue($name, $val, $RegistryValueKind)
        Publish-Env
    }
}

function search_in_path($target) {
    $path = (env 'PATH' $false) + ';' + (env 'PATH' $true)
    foreach ($dir in $path.split(';')) {
        if (Test-Path "$dir\$target" -PathType leaf) {
            return "$dir\$target"
        }
    }
}

function ensure_in_path($dir, $global) {
    $path = env 'PATH' $global
    $dir = fullpath $dir
    if ($path -notmatch [regex]::escape($dir)) {
        Write-Output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."

        env 'PATH' $global "$dir;$path" # for future sessions...
        $env:PATH = "$dir;$env:PATH" # for this session
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
    $null, $currpath = strip_path (env 'path' $global) $dir
    env 'path' $global "$dir;$currpath"

    # this session
    $null, $env:PATH = strip_path $env:PATH $dir
    $env:PATH = "$dir;$env:PATH"
}

function remove_from_path($dir, $global) {
    $dir = fullpath $dir

    # future sessions
    $was_in_path, $newpath = strip_path (env 'path' $global) $dir
    if ($was_in_path) {
        Write-Output "Removing $(friendly_path $dir) from your path."
        env 'path' $global $newpath
    }

    # current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if ($was_in_path) { $env:PATH = $newpath }
}
