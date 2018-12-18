FROM microsoft/windowsservercore:1803 as servercore

LABEL org.label-schema.maintainer="Jakub 'Ash258' Čábera <cabera.jakub@gmail.com>" \
      org.label-schema.description="Servercore image for scoop's core testing." \
      org.label-schema.url="https://github.com/lukesampson/scoop"

ENV SCOOP "C:\SCOOP"
ENV SCOOP_HOME "C:\SCOOP\apps\scoop\current"

RUN powershell.exe -NoLogo -NoExit -Command " \
        @('shims', 'persist', 'modules', 'cache') | ForEach-Object { New-Item """$env:SCOOP\$_""" -Type Directory }; \
        $path = $env:path + ';c:\SCOOP\shims;c:\SCOOP\apps\scoop\current\bin'; \
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name Path -Value $path; \
        "

ENTRYPOINT powershell.exe -NoLogo -NoExit
