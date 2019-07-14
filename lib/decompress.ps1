function Test-7zipRequirement {
    [CmdletBinding(DefaultParameterSetName = "Manifest")]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Manifest")]
        [PSObject]
        $Manifest,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Manifest")]
        [String]
        $Architecture,
        [Parameter(Mandatory = $true, ParameterSetName = "File")]
        [String]
        $File
    )
    if ($File) {
        return $File -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
    } else {
        $URL = url $Manifest $Architecture
        $Installer = installer $Manifest $Architecture
        if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
            return $false
        } elseif (($Installer.type -eq "nsis")) {
            return $true
        } else {
            return ($URL | Where-Object { Test-7zipRequirement -File $_ }).Count -gt 0
        }
    }
}

function Test-LessmsiRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $Manifest,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $Architecture
    )
    $URL = url $Manifest $Architecture
    if ((get_config MSIEXTRACT_USE_LESSMSI)) {
        return ($URL | Where-Object { $_ -match '\.msi$' }).Count -gt 0
    } else {
        return $false
    }
}

function Test-InnounpRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $Manifest,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $Architecture
    )
    return (installer $Manifest $Architecture).type -eq 'inno'
}

function Test-DarkRequirement {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSObject]
        $Manifest,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $Architecture
    )
    return (installer $Manifest $Architecture).type -eq 'wix'
}

function Expand-7zipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
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
    if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
        try {
            $7zPath = (Get-Command '7z' -CommandType Application | Select-Object -First 1).Source
        } catch [System.Management.Automation.CommandNotFoundException] {
            abort "Cannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
        }
    } else {
        $7zPath = Get-HelperPath -Helper 7zip
    }
    $LogPath = "$(Split-Path $Path)\7zip.log"
    $ArgList = @('x', "`"$Path`"", "-o`"$DestinationPath`"", '-y')
    $IsTar = ((strip_ext $Path) -match '\.tar$') -or ($Path -match '\.t[abgpx]z2?$')
    if (!$IsTar -and $ExtractDir) {
        $ArgList += "-ir!$ExtractDir\*"
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
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (!$IsTar -and $ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $DestinationPath | Out-Null
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($IsTar) {
        # Check for tar
        $Status = Invoke-ExternalCommand $7zPath @('l', "`"$Path`"") -LogPath $LogPath
        if ($Status) {
            $TarFile = (Get-Content -Path $LogPath)[-4] -replace '.{53}(.*)', '$1' # get inner tar file name
            Expand-7zipArchive -Path "$DestinationPath\$TarFile" -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
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
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $DestinationPath = $DestinationPath.TrimEnd("\")
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = "$DestinationPath\_tmp"
    }
    if ((get_config MSIEXTRACT_USE_LESSMSI)) {
        $MsiPath = Get-HelperPath -Helper Lessmsi
        $ArgList = @('x', "`"$Path`"", "`"$DestinationPath\\`"")
    } else {
        $MsiPath = 'msiexec.exe'
        $ArgList = @('/a', "`"$Path`"", '/qn', "TARGETDIR=`"$DestinationPath\\SourceDir`"")
    }
    $LogPath = "$(Split-Path $Path)\msi.log"
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand $MsiPath $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if ($ExtractDir -and (Test-Path "$DestinationPath\SourceDir")) {
        movedir "$DestinationPath\SourceDir\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Directory -Path $DestinationPath
    } elseif ($ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Directory -Path $DestinationPath
    } elseif (Test-Path "$DestinationPath\SourceDir") {
        movedir "$DestinationPath\SourceDir" $DestinationPath | Out-Null
    }
    if (($DestinationPath -ne (Split-Path $Path)) -and (Test-Path "$DestinationPath\$(fname $Path)")) {
        Remove-Item "$DestinationPath\$(fname $Path)" -Force
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $LogPath = "$(Split-Path $Path)\innounp.log"
    $ArgList = @('-x', "-d`"$DestinationPath`"", "`"$Path`"", '-y')
    switch -Regex ($ExtractDir) {
        "^\.$" { break } # Suppress '-cDIR' param
        "^[^{].*" { $ArgList += "-c`"{app}\$ExtractDir`""; break }
        "^{.*" { $ArgList += "-c`"$ExtractDir`""; break }
        Default { $ArgList += "-c`"{app}`"" }
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Innounp) $ArgList -LogPath $LogPath
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

function Expand-ZipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Switch]
        $Removal
    )
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = "$DestinationPath\_tmp"
    }
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
    if ($ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Directory -Path $DestinationPath
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
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
    Expand-MsiArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function unpack_inno($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-InnoArchive'
    Expand-InnoArchive -Path $path -DestinationPath $to -Removal:$removal @args
}

function extract_zip($path, $to, $removal) {
    Show-DeprecatedWarning $MyInvocation 'Expand-ZipArchive'
    Expand-ZipArchive -Path $path -DestinationPath $to -Removal:$removal
}

function Expand-NsisInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $Architecture,
        [Switch]
        $Removal
    )
    Expand-7ZipArchive -Path $Path -DestinationPath $DestinationPath -Removal:$Removal
    if (Test-Path "$DestinationPath\`$PLUGINSDIR\app-64.7z") {
        if ($Architecture -eq "64bit") {
            Expand-7ZipArchive -Path "$DestinationPath\`$PLUGINSDIR\app-64.7z" -DestinationPath $DestinationPath
        } else {
            abort "Software doesn't support $Architecture architecture!"
        }
    } elseif (Test-Path "$DestinationPath\`$PLUGINSDIR\app-32.7z") {
        Expand-7ZipArchive -Path "$DestinationPath\`$PLUGINSDIR\app-32.7z" -DestinationPath $DestinationPath
    }
    @("*uninst*", "`$*") | ForEach-Object { Get-Item "$DestinationPath\$_" | Remove-Item -Recurse -Force }
}

function Expand-WixInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String[]]
        $Exclude,
        [Switch]
        $Removal
    )
    Expand-DarkArchive -Path $Path -DestinationPath (ensure "$DestinationPath\_tmp") -Removal:$Removal
    if ($Exclude) {
        Remove-Item "$DestinationPath\_tmp\AttachedContainer\*.msi" -Include $Exclude -Force
    }
    Get-ChildItem "$DestinationPath\_tmp\AttachedContainer\*.msi" | ForEach-Object { Expand-MsiArchive $_ $DestinationPath }
    Remove-Directory -Path "$DestinationPath\_tmp"
}

function ConvertFrom-Inno {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [System.Array]
        $InputObject,
        [String[]]
        $Include,
        [String[]]
        $Exclude
    )

    $FileList = New-Object System.Collections.Generic.List[System.Object]
    $Files = $InputObject -match '^Source:'
    foreach ($File in $Files) {
        if ($File -match 'Source: "(?<source>(?<srcdir>[^\\]*).*?)"; DestDir: "(?<destdir>.*?)"; (?:DestName: "(?<destname>.*?)"; )?(?:Components: (?<components>.*?);)?') {
            $FileList.Add([PSCustomObject]@{source = $Matches.source; srcdir = $Matches.srcdir; destdir = $Matches.destdir; destname = $Matches.destname; components = $Matches.components })
        }
    }
    if ($FileList.components) {
        $Comps = $FileList.components | Select-Object -Unique
        $IncludeComps = @()
        $ExcludeComps = @()
        if ($Include) {
            $Include = $Include -split '\\' | Select-Object -Unique
            foreach ($IncFile in $Include) {
                $IncFile = '\b' + [Regex]::Escape($IncFile) + '\b'
                $IncludeComps += $Comps | Where-Object {
                    ($_ -match "$IncFile") -and ($_ -notmatch "not[^(]*?\(?[^(]*?$IncFile")
                }
                $ExcludeComps += $Comps | Where-Object { $_ -match "not[^(]*?\(?[^(]*?$IncFile" }
            }
        }
        if ($Exclude) {
            foreach ($ExcFile in $Exclude) {
                $ExcFile = '\b' + [Regex]::Escape($ExcFile) + '\b'
                $ExcludeComps += $Comps | Where-Object { ($_ -match "$ExcFile") -and ($_ -notmatch "not[^(]*?\(?[^(]*?$ExcFile") -and ($_ -notmatch "or[^(]*?$ExcFile") -and ($_ -notmatch "$ExcFile[^(]*?or") }
            }
            $IncludeComps = $IncludeComps | Where-Object { $_ -notin $ExcludeComps }
        }
        $Included = $FileList | Where-Object { $_.components -in $IncludeComps }
        $Excluded = $FileList | Where-Object { $_.components -in $ExcludeComps }
    }

    return @{
        FileList = $FileList;
        Excluded = $Excluded;
        Included = $Included;
        Extracted = ($FileList.srcdir | Select-Object -Unique) -ne '{tmp}'
    }
}

function Expand-InnoInstaller {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [String[]]
        $Include,
        [String[]]
        $Exclude,
        [Switch]
        $Removal
    )
    if ($ExtractDir) {
        Expand-InnoArchive -Path $Path -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal:$Removal
    } else {
        Expand-InnoArchive -Path $Path -DestinationPath $DestinationPath -ExtractDir '.' -Switches 'install_script.iss' # Just extract install script
        $InstallScript = Get-Content -Path "$DestinationPath\install_script.iss"
        $InnoFiles = ConvertFrom-Inno -InputObject $InstallScript -Include $Include -Exclude ($Exclude -notlike '{*}')
        $InnoFiles.Extracted | Where-Object { $_ -notin ($Exclude -like '{*}') } | ForEach-Object {
            Expand-InnoArchive -Path $Path -DestinationPath $DestinationPath -ExtractDir $_ -Switches '-a'
        }
        if ($InnoFiles.Excluded) {
            ($InnoFiles.Excluded.source -replace "{.*?}", "$DestinationPath") | Remove-Item -Force -ErrorAction Ignore
        }
        if ($InnoFiles.Included) {
            $InnoFiles.Included | Where-Object { $_.source -match ',' } | Rename-Item -Path { $_.source -replace "{.*?}", "$DestinationPath" } -NewName { $_.destname } -Force -ErrorAction Ignore
        }
        Get-ChildItem -Path $DestinationPath -Filter '*,*' -Recurse | Rename-Item -NewName { $_.name -Replace ',\d', '' } -Force -ErrorAction Ignore
        Get-ChildItem -Path $DestinationPath -Filter '*,*' -Recurse | Remove-Item -Force -ErrorAction Ignore
        Remove-Directory -Path $DestinationPath -OnlyEmpty
        Remove-Item -Path "$DestinationPath\install_script.iss" -Force

        if ($Removal) {
            # Remove original archive file
            Remove-Item -Path $Path -Force
        }
    }
}
