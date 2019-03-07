function requires_7zip($manifest, $architecture) {
    foreach($dlurl in @(url $manifest $architecture)) {
        if(file_requires_7zip $dlurl) { return $true }
    }
}

function requires_lessmsi ($manifest, $architecture) {
    $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
    if (!$useLessMsi) { return $false }

    $(url $manifest $architecture | Where-Object {
        $_ -match '\.(msi)$'
    } | Measure-Object | Select-Object -exp count) -gt 0
}

function file_requires_7zip($fname) {
    $fname -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh)|(nupkg))$'
}

function extract_7zip($path, $to, $recurse) {
    $output = 7z x "$path" -o"$to" -y
    if($lastexitcode -ne 0) { abort "Exit code was $lastexitcode." }

    # check for tar
    $tar = (split-path $path -leaf) -replace '\.[^\.]*$', ''
    if($tar -match '\.tar$') {
        if(test-path "$to\$tar") { extract_7zip "$to\$tar" $to $true }
    }

    if($recurse) { Remove-Item $path } # clean up intermediate files
}

function extract_msi($path, $to) {
    $logfile = "$(split-path $path)\msi.log"
    $ok = run 'msiexec' @('/a', "`"$path`"", '/qn', "TARGETDIR=`"$to`"", "/lwe `"$logfile`"")
    if(!$ok) { abort "Failed to extract files from $path.`nLog file:`n  $(friendly_path $logfile)" }
    if(test-path $logfile) { Remove-Item $logfile }
}

function lessmsi_config ($extract_dir) {
    $extract_fn = 'extract_lessmsi'
    if ($extract_dir) {
        $extract_dir = join-path SourceDir $extract_dir
    } else {
        $extract_dir = "SourceDir"
    }

    $extract_fn, $extract_dir
}

function extract_lessmsi($path, $to) {
    Invoke-Expression "lessmsi x `"$path`" `"$to\`""
}

function unpack_inno($fname, $manifest, $dir) {
    if (!$manifest.innosetup) { return }

    write-host "Unpacking innosetup... " -nonewline
    innounp -x -d"$dir\_scoop_unpack" "$dir\$fname" > "$dir\innounp.log"
    if ($lastexitcode -ne 0) {
        abort "Failed to unpack innosetup file. See $dir\innounp.log"
    }

    Get-ChildItem "$dir\_scoop_unpack\{app}" -r | Move-Item -dest "$dir" -force

    Remove-Item -r -force "$dir\_scoop_unpack"

    Remove-Item "$dir\$fname"
    Write-Host "done." -f Green
}

function extract_zip($path, $to) {
    if (!(test-path $path)) { abort "can't find $path to unzip"}
    try { add-type -assembly "System.IO.Compression.FileSystem" -ea stop }
    catch { unzip_old $path $to; return } # for .net earlier than 4.5
    $retries = 0
    while ($retries -le 10) {
        if ($retries -eq 10) {
            if (7zip_installed) {
                extract_7zip $path $to $false
                return
            } else {
                abort "Unzip failed: Windows can't unzip because a process is locking the file.`nRun 'scoop install 7zip' and try again."
            }
        }
        if (isFileLocked $path) {
            write-host "Waiting for $path to be unlocked by another process... ($retries/10)"
            $retries++
            Start-Sleep -s 2
        } else {
            break
        }
    }

    try {
        [io.compression.zipfile]::extracttodirectory($path, $to)
    } catch [system.io.pathtoolongexception] {
        # try to fall back to 7zip if path is too long
        if (7zip_installed) {
            extract_7zip $path $to $false
            return
        } else {
            abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
        }
    } catch [system.io.ioexception] {
        if (7zip_installed) {
            extract_7zip $path $to $false
            return
        } else {
            abort "Unzip failed: Windows can't handle the file names in this zip file.`nRun 'scoop install 7zip' and try again."
        }
    } catch {
        abort "Unzip failed: $_"
    }
}

function unzip_old($path, $to) {
    # fallback for .net earlier than 4.5
    $shell = (new-object -com shell.application -strict)
    $zipfiles = $shell.namespace("$path").items()
    $to = ensure $to
    $shell.namespace("$to").copyHere($zipfiles, 4) # 4 = don't show progress dialog
}
