Param([Switch]$Fast)
Push-Location $PSScriptRoot

try {
    if (!$Fast) {
        Write-Host 'Install dependencies ...'
        & "$PSScriptRoot\install.ps1"
        if ($LASTEXITCODE -ne 0) {
            throw "install.ps1 failed with exit code $LASTEXITCODE"
        }
    }

    $output = "$PSScriptRoot\bin"
    Write-Output 'Compiling Scoop.SemVer.cs ...'
    & "$PSScriptRoot\packages\Microsoft.Net.Compilers.Toolset\tasks\net472\csc.exe" -deterministic -platform:anycpu -nologo -optimize -langversion:9.0 -target:library -out:"$output\Scoop.SemVer.dll" Scoop.SemVer.cs
    # Without the check the script would checksum the stale DLL that is already in bin.
    if ($LASTEXITCODE -ne 0) {
        throw "csc.exe failed with exit code $LASTEXITCODE"
    }

    Write-Output 'Computing checksums ...'
    Remove-Item "$PSScriptRoot\bin\checksum.sha256" -ErrorAction Ignore
    Remove-Item "$PSScriptRoot\bin\checksum.sha512" -ErrorAction Ignore
    Get-ChildItem "$PSScriptRoot\bin\*" -Include *.exe, *.dll | ForEach-Object {
        "$((Get-FileHash -Path $_ -Algorithm SHA256).Hash.ToLower()) *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha256" -Append -Encoding oem
        "$((Get-FileHash -Path $_ -Algorithm SHA512).Hash.ToLower()) *$($_.Name)" | Out-File "$PSScriptRoot\bin\checksum.sha512" -Append -Encoding oem
    }
} finally {
    Pop-Location
}
