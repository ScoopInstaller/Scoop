function requires_7zip($manifest, $architecture) {
    if (get_config 7ZIPEXTRACT_USE_EXTERNAL) {
        return $false
    } else {
        return (@(url $manifest $architecture) | Where-Object { file_requires_7zip $_ }).Count -gt 0
    }
}

function requires_lessmsi ($manifest, $architecture) {
    if (get_config MSIEXTRACT_USE_LESSMSI) {
        return (@(url $manifest $architecture) | Where-Object { $_ -match '\.msi$' }).Count -gt 0
    } else {
        return $false
    }
}

function file_requires_7zip($fname) {
    $fname -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
}

function extract_7zip($path, $to, $recurse) {
    $logfile = "$(Split-Path $path)\7zip.log"
    if (get_config 7ZIPEXTRACT_USE_EXTERNAL) {
        try {
            7z x "$path" -o"$to" -y | Out-File $logfile
        } catch [System.Management.Automation.CommandNotFoundException] {
            abort "Cannot find '7Zip (7z.exe)' while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' and try again."
        }
    } else {
        &(file_path 7zip 7z.exe) x "$path" -o"$to" -y | Out-File $logfile
    }
    if ($LASTEXITCODE -ne 0) {
        abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ((strip_ext (fname $path)) -match '\.tar$' -or (fname $path) -match '\.tgz$') {
        # Check for tar
        $listfiles = &(file_path 7zip 7z.exe) l "$path"
        if ($LASTEXITCODE -eq 0) {
            $tar = ([Regex]"(\S*.tar)$").Matches($listfiles[-3]).Value # get inner tar file name
            extract_7zip "$to\$tar" $to $true
        } else {
            abort "Failed to list files in $path.`nNot a 7Zip supported compressed file."
        }
    }
    if ($recurse) {
        # Clean up compressed files
        Remove-Item $path -Force
    }
}

function extract_msi($path, $to, $recurse) {
    $logfile = "$(split-path $path)\msi.log"
    if (get_config MSIEXTRACT_USE_LESSMSI) {
        &(file_path lessmsi lessmsi.exe) x "$path" "$to\" | Out-File $logfile
        if ($LASTEXITCODE -ne 0) {
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
        Remove-Item "$to\$(fname $path)" -Force
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ($recurse) {
        # Clean up compressed files
        Remove-Item $path -Force
    }
}

function extract_inno($path, $to, $recurse) {
    $logfile = "$(Split-Path $path)\innounp.log"
    &(file_path innounp innounp.exe) -x -d"$to" -c'{app}' "$path" -y | Out-File $logfile
    if ($LASTEXITCODE -ne 0) {
        abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)"
    }
    if (Test-Path $logfile) {
        Remove-Item $logfile -Force
    }
    if ($recurse) {
        # Clean up compressed files
        Remove-Item $path -Force
    }
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
        # Clean up compressed files
        Remove-Item $path -Force
    }
}

function unpack_inno($path, $to) {
    extract_inno $path $to $true
}
