Param([Switch]$Fast)
Push-Location $PSScriptRoot
. "$PSScriptRoot\..\..\lib\core.ps1"
. "$PSScriptRoot\..\..\lib\install.ps1"

if (!$Fast) {
    Write-Host "Install dependencies ..."
    & "$PSScriptRoot\install.ps1"
}

$output = "$PSScriptRoot\bin"
Write-Output 'Compiling shim.cs ...'
& "$PSScriptRoot\packages\Microsoft.Net.Compilers.Toolset\tasks\net472\csc.exe" -deterministic -platform:anycpu -nologo -optimize -target:exe -out:"$output\shim.exe" shim.cs

Write-Output 'Computing checksums ...'
Remove-Item "$PSScriptRoot\bin\checksum.sha256" -ErrorAction Ignore
Remove-Item "$PSScriptRoot\bin\checksum.sha512" -ErrorAction Ignore
Get-ChildItem "$PSScriptRoot\bin\*" -Include *.exe, *.dll | ForEach-Object {
    "$(compute_hash $_ 'sha256') *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha256" -Append -Encoding oem
    "$(compute_hash $_ 'sha512') *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha512" -Append -Encoding oem
}
Pop-Location
