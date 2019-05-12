function Test-7zipRequirement {
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
            return ($URL | Where-Object { Test-7zipRequirement -File $_ }).Count -gt 0
        }
    } else {
        return $File -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
    }
}

function Test-LessmsiRequirement {
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

function Expand-7zipArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [ValidateSet("All", "Skip", "Rename")]
        [String]
        $Overwrite,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $LogLocation = "$(Split-Path $Path)\7zip.log"
    switch ($Overwrite) {
        "All" { $Switches += " -aoa" }
        "Skip" { $Switches += " -aos" }
        "Rename" { $Switches += " -aou" }
    }
    if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
        try {
            7z x "$Path" -o"$DestinationPath" (-split $Switches) -y | Out-File $LogLocation
        } catch [System.Management.Automation.CommandNotFoundException] {
            abort "Cannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
        }
    } else {
        & (Get-HelperPath -Helper 7zip) x "$Path" -o"$DestinationPath" (-split $Switches) -y | Out-File $LogLocation
    }
    if ($LASTEXITCODE -ne 0) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogLocation)"
    }
    if (Test-Path $LogLocation) {
        Remove-Item $LogLocation -Force
    }
    if ((strip_ext $Path) -match '\.tar$' -or $Path -match '\.tgz$') {
        # Check for tar
        $ArchivedFile = & (Get-HelperPath -Helper 7zip) l "$Path"
        if ($LASTEXITCODE -eq 0) {
            $TarFile = $ArchivedFile[-3] -replace '.{53}(.*)', '$1' # get inner tar file name
            Expand-7zipArchive "$DestinationPath\$TarFile" $DestinationPath -Removal
        } else {
            abort "Failed to list files in $Path.`nNot a 7-Zip supported archive file."
        }
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-MsiArchive {
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
        & (Get-HelperPath -Helper Lessmsi) x "$Path" "$DestinationPath\" | Out-File $LogLocation
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
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $LogLocation = "$(Split-Path $Path)\innounp.log"
    & (Get-HelperPath -Helper Innounp) -x -d"$DestinationPath" -c'{app}' "$Path" (-split $Switches) -y | Out-File $LogLocation
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
            if (Test-HelperInstalled -Helper 7zip) {
                Expand-7zipArchive $Path $DestinationPath -Removal
                return
            } else {
                abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch [System.IO.IOException] {
            if (Test-HelperInstalled -Helper 7zip) {
                Expand-7zipArchive $Path $DestinationPath -Removal
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

function Expand-DarkArchive {
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
    $LogLocation = "$(Split-Path $Path)\dark.log"
    & (Get-HelperPath -Helper Dark) -nologo -x "$DestinationPath" "$Path" | Out-File $LogLocation
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

function extract_7zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-7zipArchive'
    Expand-7zipArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function extract_msi($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-MsiArchive'
    Expand-MsiArchive -Path $path -DestinationPath $to -Removal:$removal
}

function unpack_inno($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-InnoArchive'
    Expand-InnoArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function extract_zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-ZipArchive'
    Expand-ZipArchive -Path $path -DestinationPath $to -Removal:$removal
}
