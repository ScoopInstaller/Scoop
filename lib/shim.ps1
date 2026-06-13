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
        $binaryReader.Close()
        $fileStream.Close()
    }
    return $true
}

function get_app_name($path) {
    if ((Test-Path (appsdir $false)) -and ($path -match "$([Regex]::Escape($(Convert-Path (appsdir $false))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } elseif ((Test-Path (appsdir $true)) -and ($path -match "$([Regex]::Escape($(Convert-Path (appsdir $true))))[/\\]([^/\\]+)")) {
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
    $content = (Get-Content $shim -Encoding UTF8) -join ' '
    return get_app_name $content
}

function Get-ShimTarget($ShimPath) {
    if ($ShimPath) {
        $shimTarget = if ($ShimPath.EndsWith('.shim')) {
            (Get-Content -Path $ShimPath | Select-Object -First 1).Replace('path = ', '').Replace('"', '')
        } else {
            ((Select-String -Path $ShimPath -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
        }
        if (!$shimTarget) {
            $shimTarget = ((Select-String -Path $ShimPath -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
        }
        $shimTarget | Convert-Path -ErrorAction SilentlyContinue
    }
}

function warn_on_overwrite($shim, $path) {
    if (!(Test-Path $shim)) {
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
    if (!(Test-Path $path)) { abort "Can't shim '$(fname $path)': couldn't find '$path'." }
    $abs_shimdir = ensure (shimdir $global)
    Add-Path -Path $abs_shimdir -Global:$global
    if (!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower())"

    # convert to relative path
    $resolved_path = Convert-Path $path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path -Relative $resolved_path
    Pop-Location

    if ($path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        warn_on_overwrite "$shim.shim" $path
        Copy-Item (get_shim_path) "$shim.exe" -Force
        Write-Output "path = `"$resolved_path`"" | Out-UTF8File "$shim.shim"
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
        { $_ -in @('cs', 'scoopcs') } { "$(versiondir 'scoop' 'current')\supporting\shims\cs\shim.exe" }
        { $_ -in @('cpp', '71', 'kiennq') } { "$(versiondir 'scoop' 'current')\supporting\shims\cpp\shim.exe" }
        'default' { "$(versiondir 'scoop' 'current')\supporting\shims\cs\shim.exe" }
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

        if (Test-Path "$dir\$target" -PathType leaf) {
            $bin = "$dir\$target"
        } elseif (Test-Path $target -PathType leaf) {
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
        if ($app -and (Test-Path -Path $altShimPath -PathType Leaf)) {
            Write-Output "Removing shim '$name$_.$app'."
            Remove-Item $altShimPath
        } elseif (Test-Path -Path $shimPath -PathType Leaf) {
            Write-Output "Removing shim '$name$_'."
            Remove-Item $shimPath
            $oldShims = Get-Item -Path "$shimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
            if ($null -eq $oldShims) {
                if ($_ -eq '.shim') {
                    Write-Output "Removing shim '$name.exe'."
                    Remove-Item -Path "$shimdir\$name.exe"
                }
            } else {
                (@($oldShims) | Sort-Object -Property LastWriteTimeUtc)[-1] | Rename-Item -NewName { $_.Name -replace '\.[^.]*$', '' }
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
    $altShims = Get-Item -Path "$ShimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
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
