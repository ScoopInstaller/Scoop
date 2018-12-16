FROM microsoft/windowsservercore:1803 as servercore

ENV SCOOP "C:\SCOOP"
ENV SCOOP_HOME "C:\SCOOP\apps\scoop\current"

COPY /bucket/yamTEST C:/SCOOP/buckets/yamTEST

RUN powershell.exe -NoLogo -NoExit -Command " \
        @('shims', 'persist', 'modules', 'cache') | ForEach-Object { New-Item """$env:SCOOP\$_""" -Type Directory }; \
        $path = $env:path + ';c:\SCOOP\apps\scoop\current\bin'; \
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name Path -Value $path; \
        "

ENTRYPOINT powershell.exe -NoLogo -NoExit
