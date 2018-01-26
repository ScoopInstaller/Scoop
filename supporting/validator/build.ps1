Push-Location $psscriptroot
Invoke-Expression "$psscriptroot\install.ps1"
Get-ChildItem $psscriptroot\packages\Newtonsoft.*\lib\net40\*.dll -File | ForEach-Object { Copy-Item $_ $psscriptroot }
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:library /reference:Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll Scoop.Validator.cs
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:exe /reference:Scoop.Validator.dll,Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll validator.cs
Pop-Location
