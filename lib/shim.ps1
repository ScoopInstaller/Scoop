# Shim-related functions: creating, removing, and managing shims.

function Get-PESubsystem($filePath) {
    try {
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)

        $fileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $binaryReader.ReadInt32()

        $fileStream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fileHeaderOffset = $fileStream.Position

        $fileStream.Seek(18, [System.IO.SeekOrigin]::Current) | Out-Null
        $fileStream.Seek($fileHeaderOffset + 0x5C, [System.IO.SeekOrigin]::Begin) | Out-Null

        return $binaryReader.ReadInt16()
    } catch {
        return -1
    } finally {
        if ($null -ne $binaryReader) { $binaryReader.Close() }
        if ($null -ne $fileStream) { $fileStream.Close() }
    }
}

function Get-PEMachine($filePath) {
    try {
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)

        $fileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $binaryReader.ReadInt32()

        # Machine field is at PE signature (4 bytes) + offset 0 of COFF header
        $fileStream.Seek($peOffset + 4, [System.IO.SeekOrigin]::Begin) | Out-Null

        return $binaryReader.ReadUInt16()
    } catch {
        return 0
    } finally {
        if ($null -ne $binaryReader) { $binaryReader.Close() }
        if ($null -ne $fileStream) { $fileStream.Close() }
    }
}

function Set-PESubsystem($filePath, $targetSubsystem) {
    try {
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
        $binaryReader = [System.IO.BinaryReader]::new($fileStream)
        $binaryWriter = [System.IO.BinaryWriter]::new($fileStream)

        $fileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $binaryReader.ReadInt32()

        $fileStream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fileHeaderOffset = $fileStream.Position

        $fileStream.Seek(18, [System.IO.SeekOrigin]::Current) | Out-Null
        $fileStream.Seek($fileHeaderOffset + 0x5C, [System.IO.SeekOrigin]::Begin) | Out-Null

        $binaryWriter.Write([System.Int16] $targetSubsystem)
    } catch {
        return $false
    } finally {
        if ($null -ne $binaryWriter) { $binaryWriter.Close() }
        if ($null -ne $binaryReader) { $binaryReader.Close() }
        if ($null -ne $fileStream) { $fileStream.Close() }
    }
    return $true
}

function get_app_name($path) {
    if ((Test-Path -LiteralPath (appsdir $false)) -and ($path -match "$([Regex]::Escape($(Convert-Path -LiteralPath (appsdir $false))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } elseif ((Test-Path -LiteralPath (appsdir $true)) -and ($path -match "$([Regex]::Escape($(Convert-Path -LiteralPath (appsdir $true))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } else {
        $appName = ''
    }
    return $appName
}

function get_app_name_from_shim($shim) {
    if (!(Test-Path($shim))) {
        return ''
    }
    $content = (Get-Content -LiteralPath $shim -Encoding UTF8) -join ' '
    return get_app_name $content
}

function Get-ShimTarget($ShimPath) {
    if ($ShimPath) {
        # -LiteralPath, shim names may contain wildcards (#6592)
        $shimTarget = if ($ShimPath.EndsWith('.shim')) {
            (Get-Content -LiteralPath $ShimPath | Select-Object -First 1).Replace('path = ', '').Replace('"', '')
        } else {
            ((Select-String -LiteralPath $ShimPath -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
        }
        if (!$shimTarget) {
            $shimTarget = ((Select-String -LiteralPath $ShimPath -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
        }
        $shimTargetConverted = $shimTarget | Convert-Path -ErrorAction SilentlyContinue
        if (!$shimTargetConverted -and $shimTarget -and $shimTarget.Contains('\Sysnative\')) {
            $shimTarget.Replace('\Sysnative\', '\System32\') | Convert-Path -ErrorAction SilentlyContinue
        } else {
            return $shimTargetConverted
        }
    }
}

function warn_on_overwrite($shim, $path) {
    # -LiteralPath, shim names may contain wildcards (#6592)
    if (!(Test-Path -LiteralPath )) {
        return
    }
    $shim_app = get_app_name_from_shim $shim
    $path_app = get_app_name $path
    if ($shim_app -eq $path_app) {
        return
    } else {
        if (Test-Path -Path "$shim.$path_app" -PathType Leaf) {
            Remove-Item -Path "$shim.$path_app" -Force -ErrorAction SilentlyContinue
        }
        Rename-Item -Path $shim -NewName "$shim.$shim_app" -ErrorAction SilentlyContinue
    }
    $shimname = (fname $shim) -replace '\.shim$', '.exe'
    $filename = (fname $path) -replace '\.shim$', '.exe'
    warn "Overwriting shim ('$shimname' -> '$filename')$(if ($shim_app) { ' installed from ' + $shim_app })"
}

function shim($path, $global, $name, $arg) {
    # -LiteralPath, shim names and targets may contain wildcards (#6592)
    if (!(Test-Path -LiteralPath )) { abort "Can''t shim ''$(fname $path)': couldn''t find ''$path'." }
    $abs_shimdir = ensure (shimdir $global)
    Add-Path -Path $abs_shimdir -Global:$global
    if (!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower())"

    # convert to relative path
    $resolved_path = Convert-Path -LiteralPath $path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path -Relative $resolved_path
    Pop-Location

    if ($path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        warn_on_overwrite "$shim.shim" $path
        Copy-Item (get_shim_path) "$shim.exe" -Force

        $rewrote_path = $resolved_path

        # If the shim exe is x86 on a x64 OS, rewrite paths so the shim resolves correctly:
        #   System32 -> Sysnative  (x64 resolve x64 program in System32, and it should be Sysnative in x86 program)
        #   SysWOW64 -> System32   (x64 resolve x86 program in SysWOW64, and it should be System32 in x86 program)
        $shim_machine = Get-PEMachine "$shim.exe"
        # 0x014c is IMAGE_FILE_MACHINE_I386
        # https://learn.microsoft.com/en-us/windows/win32/sysinfo/image-file-machine-constants
        if ($shim_machine -eq 0x014c -and [System.Environment]::Is64BitOperatingSystem) {
            $sysdir = [System.IO.Path]::Combine($env:SystemRoot, 'System32')
            $sysnative = [System.IO.Path]::Combine($env:SystemRoot, 'Sysnative')
            $syswow = [System.IO.Path]::Combine($env:SystemRoot, 'SysWOW64')
            if ($rewrote_path -like "$sysdir\*") {
                $rewrote_path = $rewrote_path -replace [regex]::Escape($sysdir), $sysnative
            } elseif ($rewrote_path -like "$syswow\*") {
                $rewrote_path = $rewrote_path -replace [regex]::Escape($syswow), $sysdir
            }
        }

        Write-Output "path = `"$rewrote_path`"" | Out-UTF8File "$shim.shim"
        if ($arg) {
            Write-Output "args = $arg" | Out-UTF8File "$shim.shim" -Append
        }

        $target_subsystem = Get-PESubsystem $resolved_path
        if ($target_subsystem -eq 2) {
            # we only want to make shims GUI
            Write-Output "Making $shim.exe a GUI binary."
            Set-PESubsystem "$shim.exe" $target_subsystem | Out-Null
        }
    } elseif ($path -match '\.(bat|cmd)$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@`"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "MSYS2_ARG_CONV_EXCL=/C cmd.exe /C `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.ps1$') {
        # if $path points to another drive resolve-path prepends .\ which could break shims
        warn_on_overwrite "$shim.ps1" $path
        $ps1text = if ($relative_path -match '^(\.\\)?\w:.*$') {
            @(
                "# $resolved_path",
                "`$path = `"$path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                "exit `$LASTEXITCODE"
            )
        } else {
            @(
                "# $resolved_path",
                "`$path = Join-Path `$PSScriptRoot `"$relative_path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $arg @args } else { & `$path $arg @args }",
                "exit `$LASTEXITCODE"
            )
        }
        $ps1text -join "`r`n" | Out-UTF8File "$shim.ps1"

        # make ps1 accessible from cmd.exe
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@echo off",
            "where /q pwsh.exe",
            "if %errorlevel% equ 0 (",
            "    pwsh -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
            ") else (",
            "    powershell -noprofile -ex unrestricted -file `"$resolved_path`" $arg %*",
            ")"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if command -v pwsh.exe > /dev/null 2>&1; then",
            "    pwsh.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
            "else",
            "    powershell.exe -noprofile -ex unrestricted -file `"$resolved_path`" $arg `"$@`"",
            "fi"
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.jar$') {
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@pushd $(Split-Path $resolved_path -Parent)",
            "@java -jar `"$resolved_path`" $arg %*",
            "@popd"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  cd `$(wslpath -u '$(Split-Path $resolved_path -Parent)')",
            'else',
            "  cd `$(cygpath -u '$(Split-Path $resolved_path -Parent)')",
            'fi',
            "java.exe -jar `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($path -match '\.py$') {
        warn_on_overwrite "$shim.cmd" $path
        @(
            "@rem $resolved_path",
            "@python `"$resolved_path`" $arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            '#!/bin/sh',
            "# $resolved_path",
            "python.exe `"$resolved_path`" $arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } else {
        warn_on_overwrite "$shim.cmd" $path
        $quoted_arg = if ($arg.Count -gt 0) { $arg | ForEach-Object { "`"$_`"" } }
        @(
            "@rem $resolved_path",
            '@echo off',
            'bash -c "command -v wslpath >/dev/null"',
            'if %errorlevel% equ 0 (',
            "  bash `"`$(wslpath -u '$resolved_path')`" $quoted_arg %*",
            ') else (',
            "  set args=$quoted_arg %*",
            '  setlocal enabledelayedexpansion',
            '  if not "!args!"=="" set args=!args:"=""!',
            "  bash -c `"`$(cygpath -u '$resolved_path') !args!`"",
            ')'
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        warn_on_overwrite $shim $path
        @(
            '#!/bin/sh',
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  `"`$(wslpath -u '$resolved_path')`" $arg `"$@`"",
            'else',
            "  `"`$(cygpath -u '$resolved_path')`" $arg `"$@`"",
            'fi'
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    }
}

function get_shim_path() {
    $shim_version = get_config SHIM 'kiennq'
    $shim_path = switch ($shim_version) {
        'scoopcs' { "$(versiondir 'scoop' 'current')\supporting\shims\scoopcs\shim.exe" }
        '71' { "$(versiondir 'scoop' 'current')\supporting\shims\71\shim.exe" }
        'kiennq' { "$(versiondir 'scoop' 'current')\supporting\shims\kiennq\shim.exe" }
        'default' { "$(versiondir 'scoop' 'current')\supporting\shims\scoopcs\shim.exe" }
        default { warn "Unknown shim version: '$shim_version'" }
    }
    return $shim_path
}

# get target, name, arguments for shim
function shim_def($item) {
    if ($item -is [array]) { return $item }
    return $item, (strip_ext (fname $item)), $null
}

function create_shims($manifest, $dir, $global, $arch) {
    $shims = @(arch_specific 'bin' $manifest $arch)
    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $arg = shim_def $_
        Write-Output "Creating shim for '$name'."

        # -LiteralPath, bin targets may contain wildcards (#6592)
        if (Test-Path -LiteralPath "$dir\$target" -PathType leaf) {
            $bin = "$dir\$target"
        } elseif (Test-Path -LiteralPath $target -PathType leaf) {
            $bin = $target
        } else {
            $bin = (Get-Command $target).Source
        }
        if (!$bin) { abort "Can't shim '$target': File doesn't exist." }

        shim $bin $global $name (substitute $arg @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
    }
}

function rm_shim($name, $shimdir, $app) {
    '', '.shim', '.cmd', '.ps1' | ForEach-Object {
        $shimPath = "$shimdir\$name$_"
        $altShimPath = "$shimPath.$app"
        # -LiteralPath, shim names may contain wildcards (#6592)
        if ($app -and (Test-Path -LiteralPath $altShimPath -PathType Leaf)) {
            Write-Output "Removing shim '$name$_.$app'."
            Remove-Item -LiteralPath $altShimPath
        } elseif (Test-Path -LiteralPath $shimPath -PathType Leaf) {
            Write-Output "Removing shim '$name$_'."
            Remove-Item -LiteralPath $shimPath
            # a wildcard cannot be combined with -LiteralPath, so the alternatives are listed and filtered
            $oldShims = Get-ChildItem -LiteralPath $shimdir -File |
                Where-Object { $_.BaseName -eq $name -and $_.Extension -notin @('.shim', '.cmd', '.ps1') }
            if ($null -eq $oldShims) {
                if ($_ -eq '.shim') {
                    Write-Output "Removing shim '$name.exe'."
                    Remove-Item -LiteralPath "$shimdir\$name.exe"
                }
            } else {
                ($oldShims | Sort-Object -Property LastWriteTimeUtc)[-1] | Rename-Item -NewName { $_.Name -replace '\.[^.]*$', '' }
            }
        }
    }
}

function rm_shims($app, $manifest, $global, $arch) {
    $shims = @(arch_specific 'bin' $manifest $arch)

    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $null = shim_def $_
        $shimdir = shimdir $global

        rm_shim $name $shimdir $app
    }
}

function Get-ShimInfo($ShimPath) {
    $info = [Ordered]@{}
    $info.Name = strip_ext (fname $ShimPath)
    $info.Path = $ShimPath -replace 'shim$', 'exe'
    $info.Source = (get_app_name_from_shim $ShimPath) -replace '^$', 'External'
    $info.Type = if ($ShimPath.EndsWith('.ps1')) { 'ExternalScript' } else { 'Application' }
    # -LiteralPath, shim names may contain wildcards (#6592)
    $altShims = Get-ChildItem -LiteralPath (Split-Path $ShimPath -Parent) -File |
        Where-Object { $_.BaseName -eq $info.Name -and $_.Extension -notin @('.shim', '.cmd', '.ps1') }
    if ($altShims) {
        $info.Alternatives = (@($info.Source) + ($altShims | ForEach-Object { $_.Extension.Remove(0, 1) } | Select-Object -Unique)) -join ' '
    }
    $info.IsGlobal = $ShimPath.StartsWith("$globalShimDir")
    $info.IsHidden = !((Get-Command -Name $info.Name).Path -eq $info.Path)
    [PSCustomObject]$info
}

function Get-ShimPath($ShimName, $Global) {
    '.shim', '.ps1' | ForEach-Object {
        $shimPath = Join-Path (shimdir $Global) "$ShimName$_"
        if (Test-Path -LiteralPath $shimPath) {
            return $shimPath
        }
    }
}
