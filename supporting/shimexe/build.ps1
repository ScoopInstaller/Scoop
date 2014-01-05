$fwdir = gci C:\Windows\Microsoft.NET\Framework\ -dir | sort -desc | select -first 1

& "$($fwdir.fullname)\csc.exe" /nologo shim.cs
