function Test-7ZipRequirement {
    [CmdletBinding(DefaultParameterSetName = "URL")]
    [OutputType([Boolean])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "URL")]
        [String[]]
        $URL,
        [Parameter(Mandatory = $true, ParameterSetName = "File")]
        [String]
        $File
    )
    if ($URL) {
        if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
            return $false
        } else {
            return ($URL | Where-Object { Test-7ZipRequirement -File $_ }).Count -gt 0
        }
    } else {
        return $File -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
    }
}

function Test-LessMSIRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [String[]]
        $URL
    )
    if ((get_config MSIEXTRACT_USE_LESSMSI)) {
        return ($URL | Where-Object { $_ -match '\.msi$' }).Count -gt 0
    } else {
        return $false
    }
}

function Expand-7ZipArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [Switch]
        $Removal
    )
    $LogLocation = "$(Split-Path $Path)\7zip.log"
    if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
        try {
            7z x "$Path" -o"$DestinationPath" -y | Out-File $LogLocation
        } catch [System.Management.Automation.CommandNotFoundException] {
            abort "Cannot find external 7Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7Zip manually and try again."
        }
    } else {
        &(file_path 7zip 7z.exe) x "$Path" -o"$DestinationPath" -y | Out-File $LogLocation
    }
    if ($LASTEXITCODE -ne 0) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogLocation)"
    }
    if (Test-Path $LogLocation) {
        Remove-Item $LogLocation -Force
    }
    if ((strip_ext $Path) -match '\.tar$' -or $Path -match '\.tgz$') {
        # Check for tar
        $ArchivedFile = &(file_path 7zip 7z.exe) l "$Path"
        if ($LASTEXITCODE -eq 0) {
            $TarFile = $ArchivedFile[-3] -replace '.{53}(.*)', '$1' # get inner tar file name
            Expand-7ZipArchive "$DestinationPath\$TarFile" $DestinationPath -Removal
        } else {
            abort "Failed to list files in $Path.`nNot a 7Zip supported archive file."
        }
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-MSIArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [Switch]
        $Removal
    )
    $LogLocation = "$(Split-Path $Path)\msi.log"
    if ((get_config MSIEXTRACT_USE_LESSMSI)) {
        &(file_path lessmsi lessmsi.exe) x "$Path" "$DestinationPath\" | Out-File $LogLocation
        if ($LASTEXITCODE -ne 0) {
            abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogLocation)"
        }
        if (Test-Path "$DestinationPath\SourceDir") {
            movedir "$DestinationPath\SourceDir" "$DestinationPath" | Out-Null
        }
    } else {
        $ok = run 'msiexec' @('/a', "`"$Path`"", '/qn', "TARGETDIR=`"$DestinationPath`"", "/lwe `"$LogLocation`"")
        if (!$ok) {
            abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogLocation)"
        }
        Remove-Item "$DestinationPath\$(fname $Path)" -Force
    }
    if (Test-Path $LogLocation) {
        Remove-Item $LogLocation -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [Switch]
        $Removal
    )
    $LogLocation = "$(Split-Path $Path)\innounp.log"
    &(file_path innounp innounp.exe) -x -d"$DestinationPath" -c'{app}' "$Path" -y | Out-File $LogLocation
    if ($LASTEXITCODE -ne 0) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogLocation)"
    }
    if (Test-Path $LogLocation) {
        Remove-Item $LogLocation -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [Switch]
        $Removal
    )
    # All methods to unzip the file require .NET4.5+
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
        } catch [System.IO.PathTooLongException] {
            # try to fall back to 7zip if path is too long
            if (7zip_installed) {
                Expand-7ZipArchive $Path $DestinationPath -Removal
                return
            } else {
                abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch [System.IO.IOException] {
            if (7zip_installed) {
                Expand-7ZipArchive $Path $DestinationPath -Removal
                return
            } else {
                abort "Unzip failed: Windows can't handle the file names in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch {
            abort "Unzip failed: $_"
        }
    } else {
        # Use Expand-Archive to unzip in PowerShell 5+
        # Compatible with Pscx (https://github.com/Pscx/Pscx)
        Microsoft.PowerShell.Archive\Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function extract_7zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-7ZipArchive'
    Expand-7ZipArchive -Path $path -DestinationPath $to -Removal:$removal
}

function extract_msi($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-MSIArchive'
    Expand-MSIArchive -Path $path -DestinationPath $to -Removal:$removal
}

function unpack_inno($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-InnoArchive'
    Expand-InnoArchive -Path $path -DestinationPath $to -Removal:$removal
}

function extract_zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-ZipArchive'
    Expand-ZipArchive -Path $path -DestinationPath $to -Removal:$removal
}
