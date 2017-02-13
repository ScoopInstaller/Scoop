$fwdir = gci C:\Windows\Microsoft.NET\Framework\ -dir | sort -desc | select -first 1

pushd $psscriptroot
& nuget restore -solutiondirectory .
gci $psscriptroot\packages\Newtonsoft.*\lib\net45\*.dll -file | % { copy-item $_ $psscriptroot }
& "$($fwdir.fullname)\csc.exe" /platform:anycpu /nologo /optimize /target:library /reference:Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll Scoop.Validator.cs
& "$($fwdir.fullname)\csc.exe" /platform:anycpu /nologo /optimize /target:exe /reference:Scoop.Validator.dll,Newtonsoft.Json.dll,Newtonsoft.Json.Schema.dll validator.cs
popd
