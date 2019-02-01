#Requires -Version 3

# remote install:
#   iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop' # quit if anything goes wrong

if(($PSVersionTable.PSVersion.Major) -lt 3) {
    Write-Output "PowerShell 3 or greater is required to run Scoop."
    Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
    break
}

# show notification to change execution policy:
if((Get-ExecutionPolicy) -gt 'RemoteSigned' -or (Get-ExecutionPolicy) -eq 'ByPass') {
    Write-Output "PowerShell requires an execution policy of 'RemoteSigned' to run Scoop."
    Write-Output "To make this change please run:"
    Write-Output "'Set-ExecutionPolicy RemoteSigned -scope CurrentUser'"
    break
}

if([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -notcontains 'Tls12') {
    Write-Output "Scoop requires at least .NET Framework 4.5"
    Write-Output "Please download and install it first:"
    Write-Output "https://www.microsoft.com/net/download"
    break
}

# get core functions
$core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
Write-Output 'Initializing...'
Invoke-Expression (new-object net.webclient).downloadstring($core_url)

# prep
if(installed 'scoop') {
    write-host "Scoop is already installed. Run 'scoop update' to get the latest version." -f red
    # don't abort if invoked with iex that would close the PS session
    if($myinvocation.mycommand.commandtype -eq 'Script') { return } else { exit 1 }
}
$dir = ensure (versiondir 'scoop' 'current')

# download scoop zip
# TODO: Change URL
$zipurl = 'https://github.com/Ash258/scoop/archive/new-master.zip'
$zipfile = "$dir\scoop.zip"
Write-Output 'Downloading scoop...'
dl $zipurl $zipfile

Write-Output 'Extracting...'
unzip $zipfile "$dir\_tmp"
# TODO: Change
Copy-Item "$dir\_tmp\*master\*" $dir -r -force
Remove-Item "$dir\_tmp" -r -force
Remove-Item $zipfile

Write-Output 'Creating shim...'
shim "$dir\bin\scoop.ps1" $false

# download main bucket
$dir = "$scoopdir\buckets\main"
$zipurl = 'https://github.com/Ash258/Scoop-MainBucket/archive/new-master.zip'
$zipfile = "$dir\main-bucket.zip"
Write-Output 'Downloading main bucket...'
New-Item $dir -Type Directory -Force | Out-Null
dl $zipurl $zipfile

Write-Output 'Extracting...'
unzip $zipfile "$dir\_tmp"
Copy-Item "$dir\_tmp\*-master\*" $dir -r -force
Remove-Item "$dir\_tmp", $zipfile -r -force

ensure_robocopy_in_path
ensure_scoop_in_path

Write-Output "Type 'scoop help' for instructions."

$erroractionpreference = $old_erroractionpreference # Reset $erroractionpreference to original value
