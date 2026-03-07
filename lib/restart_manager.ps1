# Restart Manager API wrapper for detecting file-locking processes
# Uses Windows Restart Manager (rstrtmgr.dll) via P/Invoke

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class RestartManager {
    [StructLayout(LayoutKind.Sequential)]
    public struct RM_UNIQUE_PROCESS {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    public const int RmUnknownApp = 0;
    public const int RmMainWindow = 1;
    public const int RmOtherWindow = 2;
    public const int RmService = 3;
    public const int RmExplorer = 4;
    public const int RmConsole = 5;
    public const int RmCritical = 1000;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string strServiceShortName;
        public int ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bRestartable;
    }

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmEndSession(uint pSessionHandle);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames,
        uint nApplications, RM_UNIQUE_PROCESS[] rgApplications, uint nServices, string[] rgsServiceNames);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmGetList(uint pSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
        [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

    public static List<RM_PROCESS_INFO> GetLockingProcesses(string[] filePaths) {
        var result = new List<RM_PROCESS_INFO>();
        uint sessionHandle;
        string sessionKey = Guid.NewGuid().ToString();

        int rv = RmStartSession(out sessionHandle, 0, sessionKey);
        if (rv != 0) return result;

        try {
            rv = RmRegisterResources(sessionHandle, (uint)filePaths.Length, filePaths, 0, null, 0, null);
            if (rv != 0) return result;

            uint pnProcInfoNeeded = 0;
            uint pnProcInfo = 0;
            uint rebootReasons = 0;

            rv = RmGetList(sessionHandle, out pnProcInfoNeeded, ref pnProcInfo, null, ref rebootReasons);
            if (rv == 234 && pnProcInfoNeeded > 0) { // ERROR_MORE_DATA
                var processInfo = new RM_PROCESS_INFO[pnProcInfoNeeded];
                pnProcInfo = pnProcInfoNeeded;
                rv = RmGetList(sessionHandle, out pnProcInfoNeeded, ref pnProcInfo, processInfo, ref rebootReasons);
                if (rv == 0) {
                    for (int i = 0; i < pnProcInfo; i++) {
                        result.Add(processInfo[i]);
                    }
                }
            }
        } finally {
            RmEndSession(sessionHandle);
        }
        return result;
    }
}
'@ -ErrorAction SilentlyContinue

$rmAppTypeNames = @{
    0    = 'Unknown'
    1    = 'MainWindow'
    2    = 'OtherWindow'
    3    = 'Service'
    4    = 'Explorer'
    5    = 'Console'
    1000 = 'Critical'
}

function Get-SafeProcessPath($procObj) {
    $procPath = $null
    if ($procObj) {
        try {
            $procPath = $procObj.Path
        } catch {
            $procPath = $null
        }
    }

    return $procPath
}

function Get-LockingProcesses($appDir) {
    $files = @(Get-ChildItem -Path $appDir -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)

    if ($files.Count -eq 0) { return @() }

    $rmResults = [RestartManager]::GetLockingProcesses([string[]]$files)

    if ($rmResults.Count -eq 0) { return @() }

    $output = @()
    $seenPids = @{}
    foreach ($rm in $rmResults) {
        $procId = $rm.Process.dwProcessId
        if ($seenPids.ContainsKey($procId)) { continue }
        $seenPids[$procId] = $true

        $procObj = Get-Process -Id $procId -ErrorAction SilentlyContinue
        $procPath = Get-SafeProcessPath $procObj

        $appType = $rmAppTypeNames[[int]$rm.ApplicationType]
        if (-not $appType) { $appType = 'Unknown' }

        $output += [PSCustomObject]@{
            Id               = $procId
            Name             = if ($procObj) { $procObj.Name } else { $rm.strAppName }
            AppName          = $rm.strAppName
            Path             = $procPath
            ApplicationType  = $appType
            ServiceName      = $rm.strServiceShortName
            Restartable      = $rm.bRestartable
            MainWindowHandle = if ($procObj) { $procObj.MainWindowHandle } else { [IntPtr]::Zero }
        }
    }

    return @($output)
}

function Get-RunningProcessesInDir($appDir) {
    $pathPattern = "$appDir\*"
    $output = @()

    $allProcesses = @(Get-Process -ErrorAction SilentlyContinue)
    foreach ($procObj in $allProcesses) {
        $procPath = Get-SafeProcessPath $procObj
        if ($procPath -like $pathPattern) {
            $output += [PSCustomObject]@{
                Id               = $procObj.Id
                Name             = $procObj.Name
                AppName          = $procObj.Name
                Path             = $procPath
                ApplicationType  = 'Unknown'
                ServiceName      = $null
                Restartable      = $false
                MainWindowHandle = $procObj.MainWindowHandle
            }
        }
    }

    return @($output)
}
