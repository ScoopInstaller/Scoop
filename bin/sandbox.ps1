# SPDX-License-Identifier: MIT
# Portions Copyright (c) Microsoft Corporation. All rights reserved.

# Parse arguments

Param(
  [Parameter(Position = 0, HelpMessage = 'The Manifest to install in the Sandbox.')]
  [String] $Manifest,
  [Parameter(Position = 1, HelpMessage = 'Options to pass to scoop.')]
  [String] $Options,
  [Parameter(Position = 2, HelpMessage = 'The script to run in the Sandbox.')]
  [ScriptBlock] $Script,
  [Parameter(HelpMessage = 'The folder to map in the Sandbox.')]
  [String] $MapFolder = $pwd
)

$ErrorActionPreference = 'Stop'

$mapFolder = (Resolve-Path -Path $MapFolder).Path

if (-Not (Test-Path -Path $mapFolder -PathType Container)) {
  Write-Error -Category InvalidArgument -Message 'The provided MapFolder is not a folder.'
}

# Check if Windows Sandbox is enabled

if (-Not (Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue)) {
  Write-Error -Category NotInstalled -Message @'
Windows Sandbox does not seem to be available. Check the following URL for prerequisites and further details:
https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview

You can run the following command in an elevated PowerShell for enabling Windows Sandbox:
$ Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM'
'@
}

# Close Windows Sandbox

$sandbox = Get-Process 'WindowsSandboxClient' -ErrorAction SilentlyContinue
if ($sandbox) {
  Write-Host '--> Closing Windows Sandbox'

  $sandbox | Stop-Process
  Start-Sleep -Seconds 5

  Write-Host
}
Remove-Variable sandbox

# Initialize Temp Folder

$tempFolderName = 'SandboxTest'
$tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $tempFolderName

Remove-Item $tempFolder -Force -Recurse

New-Item $tempFolder -ItemType Directory | Out-Null

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Copy-Item -Path $Manifest -Recurse -Destination $tempFolder
}

if ($null -eq $env:SCOOP_HOME) { $env:SCOOP_HOME = "$env:USERPROFILE\scoop" }
$scoopCache = $env:SCOOP_HOME + '\cache'

Write-Host "Copying $scoopCache to $tempFolder\cache"

Copy-Item -Path $scoopCache -Recurse -Destination $tempFolder | Out-Null

$userprofileInSandbox = 'C:\Users\WDAGUtilityAccount'
$desktopInSandbox = $userprofileInSandbox + '\Desktop'
$sandboxTestInSandbox = $desktopInSandbox + '\' + $tempFolderName
$copiedCacheInSandbox = $sandboxTestInSandbox + "\cache"
$scoopCacheInSandbox = $userprofileInSandbox + "\scoop\cache"

# Create Bootstrap script

# See: https://stackoverflow.com/a/22670892/12156188
$bootstrapPs1Content = @'
function Update-EnvironmentVariables {
  foreach($level in "Machine","User") {
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
        # For Path variables, append the new values, if they're not already in there
        if($_.Name -match 'Path$') {
          $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
        }
        $_
    } | Set-Content -Path { "Env:$($_.Name)" }
  }
}

function Get-ARPTable {
  $registry_paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
  return Get-ItemProperty $registry_paths -ErrorAction SilentlyContinue |
       Select-Object DisplayName, DisplayVersion, Publisher, @{N='ProductCode'; E={$_.PSChildName}} |
       Where-Object {$null -ne $_.DisplayName }
}
'@

$bootstrapPs1Content += @"
Write-Host @'
--> Installing Scoop, 7zip, git, innounp, dark and lessmsi
'@
`$ProgressPreference = 'SilentlyContinue'

irm get.scoop.sh -outfile 'install.ps1'
.\install.ps1 -RunAsAdmin
Update-EnvironmentVariables

xcopy /I /Q /Y $copiedCacheInSandbox\*.* $scoopCacheInSandbox\

scoop install main/7zip
scoop install main/git
scoop install main/innounp
scoop install main/dark
scoop install main/lessmsi

Write-Host @'
Tip: you can type 'Update-EnvironmentVariables' to update your environment variables, such as after installing a new software.
'@


"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  $manifestFileName = Split-Path $Manifest -Leaf
  $manifestPathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $manifestFileName)

  $bootstrapPs1Content += @"
Write-Host @'

--> Saving current ARP entries
'@
`$originalARP = Get-ARPTable
Write-Host @'

--> Running: scoop install $Options $Manifest

'@

scoop install $Options --no-update-scoop $manifestPathInSandbox

Write-Host @'

--> Refreshing environment variables
'@
Update-EnvironmentVariables

Write-Host @'

--> Comparing ARP entries
'@
(Compare-Object (Get-ARPTable) `$originalARP -Property DisplayName,DisplayVersion,Publisher,ProductCode)| Select-Object -Property * -ExcludeProperty SideIndicator | Format-Table

"@
}

if (-Not [String]::IsNullOrWhiteSpace($Script)) {
  $bootstrapPs1Content += @"
Write-Host @'

--> Running the following script:

{
$Script
}

'@

$Script


"@
}

$bootstrapPs1Content += @'
Write-Host
'@

$bootstrapPs1FileName = 'Bootstrap.ps1'
$bootstrapPs1Content | Out-File (Join-Path -Path $tempFolder -ChildPath $bootstrapPs1FileName)

# Create Wsb file

$bootstrapPs1InSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $bootstrapPs1FileName)
$mapFolderInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Split-Path -Path $mapFolder -Leaf)

$sandboxTestWsbContent = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$tempFolder</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$mapFolder</HostFolder>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>PowerShell Start-Process PowerShell -WindowStyle Maximized -WorkingDirectory '$mapFolderInSandbox' -ArgumentList '-ExecutionPolicy Bypass -NoExit -NoLogo -File $bootstrapPs1InSandbox'</Command>
  </LogonCommand>
</Configuration>
"@

$sandboxTestWsbFileName = 'SandboxTest.wsb'
$sandboxTestWsbFile = Join-Path -Path $tempFolder -ChildPath $sandboxTestWsbFileName
$sandboxTestWsbContent | Out-File $sandboxTestWsbFile

Write-Host @"
--> Starting Windows Sandbox, and:
    - Mounting the following directories:
      - $tempFolder as read-only
      - $mapFolder as read-and-write
    - Installing Scoop
"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Write-Host @"
    - Installing the Manifest $manifestFileName
    - Refreshing environment variables
    - Comparing ARP Entries
"@
}

if (-Not [String]::IsNullOrWhiteSpace($Script)) {
  Write-Host @"
    - Running the following script:

{
$Script
}
"@
}

Write-Host

WindowsSandbox $SandboxTestWsbFile
