$fwdir = Get-ChildItem C:\Windows\Microsoft.NET\Framework\ -dir | sort -desc | Select-Object -First 1

Push-Location $psscriptroot
& "$($fwdir.fullname)\csc.exe" /nologo shim.cs
Pop-Location
