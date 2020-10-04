#Requires -Version 5

# remote install:
#   Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
$old_erroractionpreference = $erroractionpreference
$erroractionpreference = 'stop' # quit if anything goes wrong

if (($PSVersionTable.PSVersion.Major) -lt 5) {
    Write-Output "PowerShell 5 or later is required to run Scoop."
    Write-Output "Upgrade PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell"
    break
}

# show notification to change execution policy:
$allowedExecutionPolicy = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $allowedExecutionPolicy) {
    Write-Output "PowerShell requires an execution policy in [$($allowedExecutionPolicy -join ", ")] to run Scoop."
    Write-Output "For example, to set the execution policy to 'RemoteSigned' please run :"
    Write-Output "'Set-ExecutionPolicy RemoteSigned -scope CurrentUser'"
    break
}

if ([System.Enum]::GetNames([System.Net.SecurityProtocolType]) -notcontains 'Tls12') {
    Write-Output "Scoop requires at least .NET Framework 4.5"
    Write-Output "Please download and install it first:"
    Write-Output "https://www.microsoft.com/net/download"
    break
}

function ConvertTo-FastGitUrl {
    param (
        [Parameter(Mandatory = $True)]
        [string]$Url
    )
    $map = @{
        '//github.com/'                = '//hub.fastgit.org/';
        '//raw.githubusercontent.com/' = '//raw.fastgit.org/'
    }
    if ($map.Keys | Where-Object { $Url -match $_ }) {
        try {
            Invoke-WebRequest 'https://v2ray.com/robots.txt' -UseBasicParsing -TimeoutSec 1 | Out-Null
        } catch {
            $map.Keys | ForEach-Object { $Url = $Url -replace $_, $map[$_] }
        }
    }
    return $Url
}

# get core functions
$core_url = ConvertTo-FastGitUrl 'https://raw.githubusercontent.com/lukesampson/scoop/master/lib/core.ps1'
Write-Output 'Initializing...'
Invoke-Expression (new-object net.webclient).downloadstring($core_url)

# prep
if (installed 'scoop') {
    write-host "Scoop is already installed. Run 'scoop update' to get the latest version." -f red
    # don't abort if invoked with iex that would close the PS session
    if ($myinvocation.mycommand.commandtype -eq 'Script') { return } else { exit 1 }
}
$dir = ensure (versiondir 'scoop' 'current')

# download scoop zip
$zipurl = ConvertTo-FastGitUrl 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$dir\scoop.zip"
Write-Output 'Downloading scoop...'
dl $zipurl $zipfile

Write-Output 'Extracting...'
Add-Type -Assembly "System.IO.Compression.FileSystem"
[IO.Compression.ZipFile]::ExtractToDirectory($zipfile, "$dir\_tmp")
Copy-Item "$dir\_tmp\*master\*" $dir -Recurse -Force
Remove-Item "$dir\_tmp", $zipfile -Recurse -Force

Write-Output 'Creating shim...'
shim "$dir\bin\scoop.ps1" $false

# download main bucket
$dir = "$scoopdir\buckets\main"
$zipurl = ConvertTo-FastGitUrl 'https://github.com/ScoopInstaller/Main/archive/master.zip'
$zipfile = "$dir\main-bucket.zip"
Write-Output 'Downloading main bucket...'
New-Item $dir -Type Directory -Force | Out-Null
dl $zipurl $zipfile

Write-Output 'Extracting...'
[IO.Compression.ZipFile]::ExtractToDirectory($zipfile, "$dir\_tmp")
Copy-Item "$dir\_tmp\*-master\*" $dir -Recurse -Force
Remove-Item "$dir\_tmp", $zipfile -Recurse -Force

ensure_robocopy_in_path
ensure_scoop_in_path

scoop config lastupdate ([System.DateTime]::Now.ToString('o'))
success 'Scoop was installed successfully!'

Write-Output "Type 'scoop help' for instructions."

$erroractionpreference = $old_erroractionpreference # Reset $erroractionpreference to original value
