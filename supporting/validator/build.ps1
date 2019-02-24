Param([Switch]$Fast)
Push-Location $psscriptroot
. "$psscriptroot\..\..\lib\install.ps1"

if(!$Fast) {
    Write-Host "Install dependencies ..."
    Invoke-Expression "$psscriptroot\install.ps1"
}

$output = "$psscriptroot\bin"
if(!$Fast) {
    Get-ChildItem "$psscriptroot\packages\Newtonsoft.*\lib\net45\*.dll" -File | ForEach-Object { Copy-Item $_ $output }
}
Write-Output 'Compiling Scoop.Validator.cs ...'
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:library /reference:"$output\Newtonsoft.Json.dll","$output\Newtonsoft.Json.Schema.dll" /out:"$output\Scoop.Validator.dll" Scoop.Validator.cs
Write-Output 'Compiling validator.cs ...'
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:exe /reference:"$output\Scoop.Validator.dll","$output\Newtonsoft.Json.dll","$output\Newtonsoft.Json.Schema.dll" /out:"$output\validator.exe" validator.cs

Write-Output 'Computing checksums ...'
Remove-Item "$psscriptroot\bin\checksum.sha256" -ErrorAction Ignore
Remove-Item "$psscriptroot\bin\checksum.sha512" -ErrorAction Ignore
Get-ChildItem "$psscriptroot\bin\*" -Include *.exe,*.dll | ForEach-Object {
    "$(compute_hash $_ 'sha256') *$($_.Name)" | Out-File "$psscriptroot\bin\checksum.sha256" -Append -Encoding oem
    "$(compute_hash $_ 'sha512') *$($_.Name)" | Out-File "$psscriptroot\bin\checksum.sha512" -Append -Encoding oem
}
Pop-Location
