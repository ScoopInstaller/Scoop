Param([Switch]$Fast)
Push-Location $PSScriptRoot
. "$PSScriptRoot\..\..\lib\core.ps1"
. "$PSScriptRoot\..\..\lib\install.ps1"

if (!$Fast) {
    Write-Host "Install dependencies ..."
    & "$PSScriptRoot\install.ps1"
}

$output = "$PSScriptRoot\bin"
if (!$Fast) {
    Get-ChildItem "$PSScriptRoot\packages\Newtonsoft.*\lib\net45\*.dll" -File | ForEach-Object { Copy-Item $_ $output }
}
Write-Output 'Compiling Scoop.Validator.cs ...'
& "$PSScriptRoot\packages\Microsoft.Net.Compilers.Toolset\tasks\net472\csc.exe" -deterministic -platform:anycpu -nologo -optimize -target:library -reference:"$output\Newtonsoft.Json.dll" -reference:"$output\Newtonsoft.Json.Schema.dll" -out:"$output\Scoop.Validator.dll" Scoop.Validator.cs
Write-Output 'Compiling validator.cs ...'
& "$PSScriptRoot\packages\Microsoft.Net.Compilers.Toolset\tasks\net472\csc.exe" -deterministic -platform:anycpu -nologo -optimize -target:exe -reference:"$output\Scoop.Validator.dll" -reference:"$output\Newtonsoft.Json.dll" -reference:"$output\Newtonsoft.Json.Schema.dll" -out:"$output\validator.exe" validator.cs

Write-Output 'Computing checksums ...'
Remove-Item "$PSScriptRoot\bin\checksum.sha256" -ErrorAction Ignore
Remove-Item "$PSScriptRoot\bin\checksum.sha512" -ErrorAction Ignore
Get-ChildItem "$PSScriptRoot\bin\*" -Include *.exe, *.dll | ForEach-Object {
    "$((Get-FileHash -Path $_ -Algorithm SHA256).Hash.ToLower()) *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha256" -Append -Encoding oem
    "$((Get-FileHash -Path $_ -Algorithm SHA512).Hash.ToLower()) *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha512" -Append -Encoding oem
}
Pop-Location
