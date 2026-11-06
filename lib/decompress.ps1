# Description: Functions for decompressing archives or installers

function Invoke-Extraction {
    param (
        [string]
        $Path,
        [string[]]
        $Name,
        [psobject]
        $Manifest,
        [Alias('Arch', 'Architecture')]
        [string]
        $ProcessorArchitecture
    )

    $uri = @(url $Manifest $ProcessorArchitecture)
    # 'extract_dir' and 'extract_to' are paired
    $extractDir = @(extract_dir $Manifest $ProcessorArchitecture)
    $extractTo = @(extract_to $Manifest $ProcessorArchitecture)
    $extracted = 0

    for ($i = 0; $i -lt $Name.Length; $i++) {
        # work out extraction method, if applicable
        $extractFn = $null
        switch -regex ($Name[$i]) {
            '\.zip$' {
                if ((Test-HelperInstalled -Helper 7zip) -or ((get_config USE_EXTERNAL_7ZIP) -and (Test-CommandAvailable 7z))) {
                    $extractFn = 'Expand-7zipArchive'
                } else {
                    $extractFn = 'Expand-ZipArchive'
                }
                continue
            }
            '\.msi$' {
                $extractFn = 'Expand-MsiArchive'
                continue
            }
            '\.exe$' {
                if ($Manifest.innosetup) {
                    $extractFn = 'Expand-InnoArchive'
                }
                continue
            }
            { Test-7zipRequirement -Uri $_ } {
                $extractFn = 'Expand-7zipArchive'
                continue
            }
        }
        if ($extractFn) {
            $fnArgs = @{
                Path            = Join-Path $Path $Name[$i]
                DestinationPath = Join-Path $Path $extractTo[$extracted]
                ExtractDir      = $extractDir[$extracted]
            }
            Write-Host "Extracting $([char]0x1b)[36m$(url_remote_filename $uri[$i])$([char]0x1b)[0m... " -NoNewline
            try {
                & $extractFn @fnArgs -Removal
                Write-Host 'Done.' -ForegroundColor Green
            } catch {
                Write-Host 'Error.' -ForegroundColor DarkRed
                throw
            } finally {
                $extracted++
            }
        }
    }
}

function Get-MsixEncodedPath {
    param([String] $Path, [String] $ExtractDir)

    if ($Path -notmatch '\.(zip|msix|appx)$') { return }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    } catch [IO.InvalidDataException] {
        # A filename override can also disguise a non-ZIP archive supported by
        # 7-Zip. Leave format validation to the existing extractor in that case.
        return
    }
    try {
        # Manifests commonly rename an MSIX download to dl.zip. Identify the package
        # by its footprint files, so ordinary ZIP filenames remain literal.
        if (!$archive.GetEntry('AppxManifest.xml') -or !$archive.GetEntry('AppxBlockMap.xml') -or !$archive.GetEntry('[Content_Types].xml')) { return }

        $prefix = ($ExtractDir -replace '\\', '/').Trim('/')
        if ($prefix) { $prefix += '/' }
        $paths = @{}
        $decodedPaths = @{}
        foreach ($entry in $archive.Entries) {
            $relative = $entry.FullName.TrimEnd('/')
            if ($prefix) {
                if (!$relative.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
                $relative = $relative.Substring($prefix.Length)
            }
            $original = ''
            $decoded = ''
            $depth = 0
            foreach ($part in $relative.Split('/')) {
                $name = [uri]::UnescapeDataString($part)
                if (!$name -or $name -eq '.' -or $name -eq '..' -or
                    $name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
                    $name.EndsWith('.') -or $name.EndsWith(' ')) {
                    throw "Unsafe MSIX filename: $($entry.FullName)"
                }
                if ($original) { $original += '/'; $decoded += '/' }
                $original += $part
                $decoded += $name
                $depth++
                if ($decodedPaths.ContainsKey($decoded) -and $decodedPaths[$decoded] -cne $original) {
                    throw "Conflicting MSIX filename: $($entry.FullName)"
                }
                $decodedPaths[$decoded] = $original
                if ($part -cne $name) {
                    $paths[$original] = [PSCustomObject]@{ Original = $original; Name = $name; Depth = $depth }
                }
            }
        }
        $paths.Values | Sort-Object @{ Expression = 'Depth'; Descending = $true }, @{ Expression = { $_.Original.Length } }
    } finally {
        $archive.Dispose()
    }
}

function Rename-MsixEncodedPath {
    param([Object[]] $Mapping, [String] $DestinationPath)

    # Children must be renamed before their parents, and each component only once:
    # an encoded literal percent sign (%2540) must become %40, not @.
    foreach ($item in $Mapping) {
        $source = Join-Path $DestinationPath $item.Original
        $target = Join-Path (Split-Path $source) $item.Name
        if (Test-Path -LiteralPath $target) {
            throw "MSIX filename already exists: $target"
        }
        Rename-Item -LiteralPath $source -NewName $item.Name -ErrorAction Stop
    }
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
        [ValidateSet('All', 'Skip', 'Rename')]
        [String]
        $Overwrite,
        [Switch]
        $Removal
    )
    $msixPaths = @(Get-MsixEncodedPath $Path $ExtractDir)
    if ((get_config USE_EXTERNAL_7ZIP)) {
        try {
            $7zPath = (Get-Command '7z' -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        } catch [System.Management.Automation.CommandNotFoundException] {
            throw "`nCannot find external 7-Zip (7z.exe) while 'use_external_7zip' is 'true'!`nRun 'scoop config use_external_7zip false' or install 7-Zip manually and try again."
        }
    } else {
        $7zPath = Get-HelperPath -Helper 7zip
    }
    $LogPath = "$(Split-Path $Path)\7zip.log"
    $DestinationPath = $DestinationPath.TrimEnd('\')
    $ArgList = @('x', $Path, "-o$DestinationPath", '-xr!*.nsis', '-y')
    $IsTar = ((strip_ext $Path) -match '\.tar$') -or ($Path -match '\.t[abgpx]z2?$')
    if (!$IsTar -and $ExtractDir) {
        $ArgList += "-ir!$ExtractDir\*"
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    switch ($Overwrite) {
        'All' { $ArgList += '-aoa' }
        'Skip' { $ArgList += '-aos' }
        'Rename' { $ArgList += '-aou' }
    }
    $Status = Invoke-ExternalCommand $7zPath $ArgList -LogPath $LogPath
    if (!$Status) {
        throw "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if ($IsTar) {
        # Check for tar
        $Status = Invoke-ExternalCommand $7zPath @('l', $Path) -LogPath $LogPath
        if ($Status) {
            # get inner tar file name
            $TarFile = (Select-String -Path $LogPath -Pattern '[^ ]*tar$').Matches.Value
            Expand-7zipArchive -Path "$DestinationPath\$TarFile" -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
        } else {
            throw "Failed to list files in $Path.`nNot a 7-Zip supported archive file."
        }
    }
    if (!$IsTar -and $ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $DestinationPath | Out-Null
        # Remove temporary directory if it is empty
        $ExtractDirTopPath = [string] "$DestinationPath\$($ExtractDir -replace '[\\/].*')"
        if ((Get-ChildItem -Path $ExtractDirTopPath -Force -ErrorAction Ignore).Count -eq 0) {
            Remove-Item -Path $ExtractDirTopPath -Recurse -Force -ErrorAction Ignore
        }
    }
    Rename-MsixEncodedPath $msixPaths $DestinationPath
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        if (($Path -replace '.*\.([^\.]*)$', '$1') -eq '001') {
            # Remove split 7-zip archive parts
            Get-ChildItem "$($Path -replace '\.[^\.]*$', '').???" | Remove-Item -Force
        } elseif (($Path -replace '.*\.part(\d+)\.rar$', '$1')[-1] -eq '1') {
            # Remove split RAR archive parts
            Get-ChildItem "$($Path -replace '\.part(\d+)\.rar$', '').part*.rar" | Remove-Item -Force
        } else {
            # Remove original archive file
            Remove-Item $Path -Force
        }
    }
}

function Expand-ZstdArchive {
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
    # TODO: Remove this function after 2024/12/31
    Show-DeprecatedWarning $MyInvocation 'Expand-7zipArchive'
    Expand-7zipArchive -Path $Path -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Switches $Switches -Removal:$Removal
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
    $DestinationPath = $DestinationPath.TrimEnd('\')
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = "$DestinationPath\_tmp"
    }
    if ((get_config USE_LESSMSI)) {
        $MsiPath = Get-HelperPath -Helper Lessmsi
        $ArgList = @('x', $Path, "$DestinationPath\")
    } else {
        $MsiPath = 'msiexec.exe'
        $ArgList = @('/a', $Path, '/qn', "TARGETDIR=$DestinationPath\SourceDir")
    }
    $LogPath = "$(Split-Path $Path)\msi.log"
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand $MsiPath $ArgList -LogPath $LogPath
    if (!$Status) {
        throw "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if ($ExtractDir -and (Test-Path "$DestinationPath\SourceDir")) {
        movedir "$DestinationPath\SourceDir\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    } elseif ($ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
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
    $ArgList = @('-x', "-d$DestinationPath", $Path, '-y')
    switch -Regex ($ExtractDir) {
        '^[^{].*' { $ArgList += "-c{app}\$ExtractDir" }
        '^{.*' { $ArgList += "-c$ExtractDir" }
        Default { $ArgList += '-c{app}' }
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Innounp) $ArgList -LogPath $LogPath
    if (!$Status) {
        throw "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
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
    $msixPaths = @(Get-MsixEncodedPath $Path $ExtractDir)
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = "$DestinationPath\_tmp"
    }
    # Disable progress bar to gain performance
    $oldProgressPreference = $ProgressPreference
    $global:ProgressPreference = 'SilentlyContinue'

    # Compatible with Pscx v3 (https://github.com/Pscx/Pscx) ('Microsoft.PowerShell.Archive' is not needed for Pscx v4)
    Microsoft.PowerShell.Archive\Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force

    $global:ProgressPreference = $oldProgressPreference
    if ($ExtractDir) {
        movedir "$DestinationPath\$ExtractDir" $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
        $DestinationPath = $OriDestinationPath
    }
    Rename-MsixEncodedPath $msixPaths $DestinationPath
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
    $DarkPath = Get-HelperPath -Helper Dark
    if ((Split-Path $DarkPath -Leaf) -eq 'wix.exe') {
        $ArgList = @('burn', 'extract', $Path, '-out', $DestinationPath, '-outba', "$DestinationPath\UX")
    } else {
        $ArgList = @('-nologo', '-x', $DestinationPath, $Path)
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand $DarkPath $ArgList -LogPath $LogPath
    if (!$Status) {
        throw "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path "$DestinationPath\WixAttachedContainer") {
        Rename-Item "$DestinationPath\WixAttachedContainer" 'AttachedContainer' -ErrorAction Ignore
    } else {
        if (Test-Path "$DestinationPath\AttachedContainer\a0") {
            $Xml = [xml](Get-Content -Raw "$DestinationPath\UX\manifest.xml" -Encoding utf8)
            $Xml.BurnManifest.UX.Payload | ForEach-Object {
                Rename-Item "$DestinationPath\UX\$($_.SourcePath)" $_.FilePath -ErrorAction Ignore
            }
            $Xml.BurnManifest.Payload | ForEach-Object {
                Rename-Item "$DestinationPath\AttachedContainer\$($_.SourcePath)" $_.FilePath -ErrorAction Ignore
            }
        }
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}
