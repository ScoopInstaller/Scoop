function requires_7zip($manifest, $architecture) {
    foreach ($dlurl in @(url $manifest $architecture)) {
        if (file_requires_7zip $dlurl) {
            return $true
        }
    }
}

function requires_lessmsi ($manifest, $architecture) {
    $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
    if (!$useLessMsi) {
        return $false
    }
    $(url $manifest $architecture | Where-Object {
            $_ -match '\.(msi)$'
        } | Measure-Object | Select-Object -exp count) -gt 0
}

function file_requires_7zip($fname) {
    $fname -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
}

function extract_7zip($path, $to, $recurse) {
    $logfile = "$(Split-Path $path)\7zip.log"
    &(file_path 7zip 7z.exe) x "$path" -o"$to" -y | Out-File "$logfile"
    if ($lastexitcode -ne 0) {
        abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ((strip_ext (fname $path)) -match '\.tar$' -or (fname $path) -match '\.tgz$') {
        $listfiles = &(file_path 7zip 7z.exe) l "$path"
        if ($lastexitcode -eq 0) {
            $tar = ([Regex]"(\S*.tar)$").Matches($listfiles[-3]).Value
            extract_7zip "$to\$tar" $to $true
        } else {
            abort "Failed to list files in $path."
        }
    } # Check for tar
    if ($recurse) {
        Remove-Item $path -Force
    } # Clean up compressed files
}

function extract_msi($path, $to, $recurse) {
    $logfile = "$(split-path $path)\msi.log"
    $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
    if ($useLessMsi) {
        &(file_path lessmsi lessmsi.exe) x "$path" "$to\" | Out-File "$logfile"
        if ($lastexitcode -ne 0) {
            abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
        }
        if (Test-Path "$to\SourceDir") {
            movedir "$to\SourceDir" "$to" | Out-Null
        }
    } else {
        $ok = run 'msiexec' @('/a', "`"$path`"", '/qn', "TARGETDIR=`"$to`"", "/lwe `"$logfile`"")
        if (!$ok) {
            abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
        }
        Remove-Item "$to\$(fname $path)"
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ($recurse) {
        Remove-Item $path -Force
    } # Clean up compressed files
}

function extract_inno($path, $to, $recurse) {
    $logfile = "$(Split-Path $path)\innounp.log"
    &(file_path innounp innounp.exe) -x -d"$to" -c"{app}" "$path" -y | Out-File "$logfile"
    if ($lastexitcode -ne 0) {
        abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ($recurse) {
        Remove-Item $path -Force
    } # Clean up compressed files
}

function extract_zip($path, $to, $recurse) {
    # All methods to unzip the file require .NET4.5+
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $to)
        } catch [System.IO.PathTooLongException] {
            # try to fall back to 7zip if path is too long
            if (7zip_installed) {
                extract_7zip $path $to $recurse
                return
            } else {
                abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch [System.IO.IOException] {
            if (7zip_installed) {
                extract_7zip $path $to $recurse
                return
            } else {
                abort "Unzip failed: Windows can't handle the file names in this zip file.`nRun 'scoop install 7zip' and try again."
            }
        } catch {
            abort "Unzip failed: $_"
        }
    } else {
        # Use Expand-Archive to unzip in PowerShell 5+
        Expand-Archive -Path $path -DestinationPath $to -Force
    }
    if ($recurse) {
        Remove-Item $path -Force
    } # Clean up compressed files
}
