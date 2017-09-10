pushd $psscriptroot
iex "$psscriptroot\install.ps1"
gci $psscriptroot\packages\Newtonsoft.*\lib\net40\*.dll -file | % { copy-item $_ $psscriptroot }
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:library /reference:Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll Scoop.Validator.cs
& "$psscriptroot\packages\Microsoft.Net.Compilers\tools\csc.exe" /deterministic /platform:anycpu /nologo /optimize /target:exe /reference:Scoop.Validator.dll,Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll validator.cs
popd
