function Test-7zipRequirement {
    [CmdletBinding(DefaultParameterSetName = "URL")]
    [OutputType([Boolean])]
    param (
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
    param (
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
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]
        $Path,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $DestinationPath,
        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [ValidateSet("All", "Skip", "Rename")]
        [String]
        $Overwrite,
        [Switch]
        $Removal
    )
    begin {
        if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
            try {
                $7zPath = (Get-Command '7z' -CommandType Application | Select-Object -First 1).Source
            } catch [System.Management.Automation.CommandNotFoundException] {
                abort "Cannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
            }
        } else {
            $7zPath = Get-HelperPath -Helper 7zip
        }
    }
    process {
        if (!$DestinationPath) {
            $DestinationPath = Split-Path -Path $Path
        }
        for ($i = 0; $i -lt $Path.Length; $i++) {
            $aPath = $Path[$i]
            if ($aDestinationPath = $DestinationPath[$i]) {
                $aDestinationPath = $DestinationPath[-1]
            }
            if ($ExtractDir) {
                if ($aExtractDir = $ExtractDir[$i]) {
                    $aExtractDir = $ExtractDir[-1]
                }
            }
            $LogPath = "$(Split-Path $aPath)\7zip.log"
            $ArgList = @('x', "`"$aPath`"", "-o`"$aDestinationPath`"", '-y')
            $IsTar = ((strip_ext $aPath) -match '\.tar$') -or ($aPath -match '\.t[abgpx]z2?$')
            if (!$IsTar -and $aExtractDir) {
                $ArgList += "-ir!$aExtractDir\*"
            }
            if ($Switches) {
                $ArgList += (-split $Switches)
            }
            switch ($Overwrite) {
                "All" { $ArgList += "-aoa" }
                "Skip" { $ArgList += "-aos" }
                "Rename" { $ArgList += "-aou" }
            }
            $Status = Invoke-ExternalCommand $7zPath $ArgList -LogPath $LogPath
            if (!$Status) {
                abort "Failed to extract files from $aPath.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
            }
            if (!$IsTar -and $aExtractDir) {
                movedir "$aDestinationPath\$aExtractDir" $aDestinationPath | Out-Null
            }
            if (Test-Path $LogPath) {
                Remove-Item $LogPath -Force
            }
            if ($IsTar) {
                # Check for tar
                $Status = Invoke-ExternalCommand $7zPath @('l', "`"$aPath`"") -LogPath $LogPath
                if ($Status) {
                    $TarFile = (Get-Content -Path $LogPath)[-4] -replace '.{53}(.*)', '$1' # get inner tar file name
                    Expand-7zipArchive -Path "$aDestinationPath\$TarFile" -DestinationPath $aDestinationPath -ExtractDir $aExtractDir -Removal
                } else {
                    abort "Failed to list files in $aPath.`nNot a 7-Zip supported archive file."
                }
            }
            if ($Removal) {
                # Remove original archive file
                Remove-Item $aPath -Force
            }
        }
    }
}

function Expand-MsiArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]
        $Path,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $DestinationPath,
        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    process {
        if (!$DestinationPath) {
            $DestinationPath = Split-Path -Path $Path
        }
        for ($i = 0; $i -lt $Path.Length; $i++) {
            $aPath = $Path[$i]
            if ($aDestinationPath = $DestinationPath[$i]) {
                $aDestinationPath = $DestinationPath[-1]
            }
            if ($ExtractDir) {
                if ($aExtractDir = $ExtractDir[$i]) {
                    $aExtractDir = $ExtractDir[-1]
                }
            }
            $aDestinationPath = $aDestinationPath.TrimEnd("\")
            if ($aExtractDir) {
                $OriDestinationPath = $aDestinationPath
                $aDestinationPath = "$aDestinationPath\_tmp"
            }
            if ((get_config MSIEXTRACT_USE_LESSMSI)) {
                $MsiPath = Get-HelperPath -Helper Lessmsi
                $ArgList = @('x', "`"$aPath`"", "`"$aDestinationPath\\`"")
            } else {
                $MsiPath = 'msiexec.exe'
                $ArgList = @('/a', "`"$aPath`"", '/qn', "TARGETDIR=`"$aDestinationPath\\SourceDir`"")
            }
            $LogPath = "$(Split-Path $aPath)\msi.log"
            if ($Switches) {
                $ArgList += (-split $Switches)
            }
            $Status = Invoke-ExternalCommand $MsiPath $ArgList -LogPath $LogPath
            if (!$Status) {
                abort "Failed to extract files from $aPath.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
            }
            if ($aExtractDir -and (Test-Path "$aDestinationPath\SourceDir")) {
                movedir "$aDestinationPath\SourceDir\$aExtractDir" $OriDestinationPath | Out-Null
                Remove-Item $aDestinationPath -Recurse -Force
            } elseif ($aExtractDir) {
                movedir "$aDestinationPath\$aExtractDir" $OriDestinationPath | Out-Null
                Remove-Item $aDestinationPath -Recurse -Force
            } elseif (Test-Path "$aDestinationPath\SourceDir") {
                movedir "$aDestinationPath\SourceDir" $aDestinationPath | Out-Null
            }
            if (($aDestinationPath -ne (Split-Path $aPath)) -and (Test-Path "$aDestinationPath\$(fname $aPath)")) {
                Remove-Item "$aDestinationPath\$(fname $aPath)" -Force
            }
            if (Test-Path $LogPath) {
                Remove-Item $LogPath -Force
            }
            if ($Removal) {
                # Remove original archive file
                Remove-Item $aPath -Force
            }
        }
    }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]
        $Path,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $DestinationPath,
        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    process {
        if (!$DestinationPath) {
            $DestinationPath = Split-Path -Path $Path
        }
        for ($i = 0; $i -lt $Path.Length; $i++) {
            $aPath = $Path[$i]
            if ($aDestinationPath = $DestinationPath[$i]) {
                $aDestinationPath = $DestinationPath[-1]
            }
            if ($ExtractDir) {
                if ($aExtractDir = $ExtractDir[$i]) {
                    $aExtractDir = $ExtractDir[-1]
                }
            }
            $LogPath = "$(Split-Path $aPath)\innounp.log"
            $ArgList = @('-x', "-d`"$aDestinationPath`"", "`"$aPath`"", '-y')
            switch -Regex ($aExtractDir) {
                "^[^{].*" { $ArgList += "-c{app}\$aExtractDir" }
                "^{.*" { $ArgList += "-c$aExtractDir" }
                Default { $ArgList += "-c{app}" }
            }
            if ($Switches) {
                $ArgList += (-split $Switches)
            }
            $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Innounp) $ArgList -LogPath $LogPath
            if (!$Status) {
                abort "Failed to extract files from $aPath.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
            }
            if (Test-Path $LogPath) {
                Remove-Item $LogPath -Force
            }
            if ($Removal) {
                # Remove original archive file
                Remove-Item $aPath -Force
            }
        }
    }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String[]]
        $Path,
        [Parameter(Position = 1, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $DestinationPath,
        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true)]
        [String[]]
        $ExtractDir,
        [Switch]
        $Removal
    )
    process {
        if (!$DestinationPath) {
            $DestinationPath = Split-Path -Path $Path
        }
        for ($i = 0; $i -lt $Path.Length; $i++) {
            $aPath = $Path[$i]
            if ($aDestinationPath = $DestinationPath[$i]) {
                $aDestinationPath = $DestinationPath[-1]
            }
            if ($ExtractDir) {
                if ($aExtractDir = $ExtractDir[$i]) {
                    $aExtractDir = $ExtractDir[-1]
                }
            }
            if ($aExtractDir) {
                $OriDestinationPath = $aDestinationPath
                $aDestinationPath = "$aDestinationPath\_tmp"
            }
            # All methods to unzip the file require .NET4.5+
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                try {
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($aPath, $aDestinationPath)
                } catch [System.IO.PathTooLongException] {
                    # try to fall back to 7zip if path is too long
                    if (Test-HelperInstalled -Helper 7zip) {
                        Expand-7zipArchive $aPath $aDestinationPath -Removal
                        return
                    } else {
                        abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
                    }
                } catch [System.IO.IOException] {
                    if (Test-HelperInstalled -Helper 7zip) {
                        Expand-7zipArchive $aPath $aDestinationPath -Removal
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
                Microsoft.PowerShell.Archive\Expand-Archive -Path $aPath -DestinationPath $aDestinationPath -Force
            }
            if ($aExtractDir) {
                movedir "$aDestinationPath\$aExtractDir" $OriDestinationPath | Out-Null
                Remove-Item $aDestinationPath -Recurse -Force
            }
            if ($Removal) {
                # Remove original archive file
                Remove-Item $aPath -Force
            }
        }
    }
}

function Expand-DarkArchive {
    [CmdletBinding()]
    param (
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
    $LogPath = "$(Split-Path $Path)\dark.log"
    $ArgList = @('-nologo', "-x `"$DestinationPath`"", "`"$Path`"")
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Dark) $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
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
