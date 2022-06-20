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
