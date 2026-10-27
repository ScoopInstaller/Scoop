# Description: Functions for creating, removing, and updating shims.

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

function Get-AppNameFromPath($Path) {
    if ((Test-Path -LiteralPath (appsdir $false)) -and ($Path -match "$([Regex]::Escape($(Convert-Path -LiteralPath (appsdir $false))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } elseif ((Test-Path -LiteralPath (appsdir $true)) -and ($Path -match "$([Regex]::Escape($(Convert-Path -LiteralPath (appsdir $true))))[/\\]([^/\\]+)")) {
        $appName = $Matches[1].ToLower()
    } else {
        $appName = ''
    }
    return $appName
}

function Get-AppNameFromShim($Shim) {
    if (!(Test-Path -LiteralPath $Shim)) {
        return ''
    }
    $content = (Get-Content -LiteralPath $Shim -Encoding UTF8) -join ' '
    return Get-AppNameFromPath $content
}

function Get-ShimTarget($ShimPath) {
    if ($ShimPath) {
        $shimTarget = if ($ShimPath.EndsWith('.shim')) {
            (Get-Content -LiteralPath $ShimPath -Encoding UTF8 | Select-Object -First 1).Replace('path = ', '').Replace('"', '')
        } else {
            ((Select-String -LiteralPath $ShimPath -Pattern '^(?:@rem|#)\s*(.*)$').Matches.Groups | Select-Object -Index 1).Value
        }
        if (!$shimTarget) {
            $shimTarget = ((Select-String -LiteralPath $ShimPath -Pattern '[''"]([^@&]*?)[''"]' -AllMatches).Matches.Groups | Select-Object -Last 1).Value
        }
        # Convert-Path binds it strictly, so the empty case the pipeline form swallowed is screened out
        $shimTargetConverted = if ($shimTarget) {
            Convert-Path -LiteralPath $shimTarget -ErrorAction SilentlyContinue
        }
        if (!$shimTargetConverted -and $shimTarget -and $shimTarget.Contains('\Sysnative\')) {
            Convert-Path -LiteralPath ($shimTarget.Replace('\Sysnative\', '\System32\')) -ErrorAction SilentlyContinue
        } else {
            return $shimTargetConverted
        }
    }
}

function Rename-ShimOnConflict($Shim, $Path) {
    if (!(Test-Path -LiteralPath $Shim)) {
        return
    }
    $shim_app = Get-AppNameFromShim $Shim
    $path_app = Get-AppNameFromPath $Path
    if ($shim_app -eq $path_app) {
        return
    } else {
        if (Test-Path -LiteralPath "$Shim.$path_app" -PathType Leaf) {
            Remove-Item -LiteralPath "$Shim.$path_app" -Force -ErrorAction SilentlyContinue
        }
        Rename-Item -LiteralPath $Shim -NewName "$Shim.$shim_app" -ErrorAction SilentlyContinue
    }
    $shimname = (fname $Shim) -replace '\.shim$', '.exe'
    $filename = (fname $Path) -replace '\.shim$', '.exe'
    warn "Overwriting shim ('$shimname' -> '$filename')$(if ($shim_app) { ' installed from ' + $shim_app })"
}

function New-Shim($Path, $Global, $Name, $Arg) {
    if (!(Test-Path -LiteralPath $Path)) { abort "Can't shim '$(fname $Path)': couldn't find '$Path'." }
    $abs_shimdir = ensure (shimdir $Global)
    Add-Path -Path $abs_shimdir -Global:$Global
    if (!$Name) { $Name = strip_ext (fname $Path) }

    $shim = "$abs_shimdir\$($Name.tolower())"

    # convert to relative path
    $resolved_path = Convert-Path -LiteralPath $Path
    Push-Location $abs_shimdir
    $relative_path = Resolve-Path -LiteralPath $resolved_path -Relative
    Pop-Location

    if ($Path -match '\.(exe|com)$') {
        # for programs with no awareness of any shell
        Rename-ShimOnConflict "$shim.shim" $Path
        Copy-Item -LiteralPath (Get-ShimTemplate) "$shim.exe" -Force

        Write-Output "path = `"$resolved_path`"" | Out-UTF8File "$shim.shim"
        if ($Arg) {
            Write-Output "args = $Arg" | Out-UTF8File "$shim.shim" -Append
        }

        $target_subsystem = Get-PESubsystem $resolved_path
        if ($target_subsystem -eq 2) {
            # we only want to make shims GUI
            Write-Output "Making $shim.exe a GUI binary."
            Set-PESubsystem "$shim.exe" $target_subsystem | Out-Null
        }
    } elseif ($Path -match '\.(bat|cmd)$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        Rename-ShimOnConflict "$shim.cmd" $Path
        @(
            "@rem $resolved_path",
            "@`"$resolved_path`" $Arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        Rename-ShimOnConflict $shim $Path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "MSYS2_ARG_CONV_EXCL=/C cmd.exe /C `"$resolved_path`" $Arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($Path -match '\.ps1$') {
        # if $Path points to another drive resolve-path prepends .\ which could break shims
        Rename-ShimOnConflict "$shim.ps1" $Path
        $ps1text = if ($relative_path -match '^(\.\\)?\w:.*$') {
            @(
                "# $resolved_path",
                "`$path = `"$Path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $Arg @args } else { & `$path $Arg @args }",
                "exit `$LASTEXITCODE"
            )
        } else {
            @(
                "# $resolved_path",
                "`$path = Join-Path `$PSScriptRoot `"$relative_path`"",
                "if (`$MyInvocation.ExpectingInput) { `$input | & `$path $Arg @args } else { & `$path $Arg @args }",
                "exit `$LASTEXITCODE"
            )
        }
        $ps1text -join "`r`n" | Out-UTF8File "$shim.ps1"

        # make ps1 accessible from cmd.exe
        Rename-ShimOnConflict "$shim.cmd" $Path
        @(
            "@rem $resolved_path",
            "@echo off",
            "where /q pwsh.exe",
            "if %errorlevel% equ 0 (",
            "    pwsh -noprofile -ex unrestricted -file `"$resolved_path`" $Arg %*",
            ") else (",
            "    powershell -noprofile -ex unrestricted -file `"$resolved_path`" $Arg %*",
            ")"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        Rename-ShimOnConflict $shim $Path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if command -v pwsh.exe > /dev/null 2>&1; then",
            "    pwsh.exe -noprofile -ex unrestricted -file `"$resolved_path`" $Arg `"$@`"",
            "else",
            "    powershell.exe -noprofile -ex unrestricted -file `"$resolved_path`" $Arg `"$@`"",
            "fi"
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($Path -match '\.jar$') {
        Rename-ShimOnConflict "$shim.cmd" $Path
        @(
            "@rem $resolved_path",
            "@pushd $(Split-Path $resolved_path -Parent)",
            "@java -jar `"$resolved_path`" $Arg %*",
            "@popd"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        Rename-ShimOnConflict $shim $Path
        @(
            "#!/bin/sh",
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  cd `$(wslpath -u '$(Split-Path $resolved_path -Parent)')",
            'else',
            "  cd `$(cygpath -u '$(Split-Path $resolved_path -Parent)')",
            'fi',
            "java.exe -jar `"$resolved_path`" $Arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } elseif ($Path -match '\.py$') {
        Rename-ShimOnConflict "$shim.cmd" $Path
        @(
            "@rem $resolved_path",
            "@python `"$resolved_path`" $Arg %*"
        ) -join "`r`n" | Out-UTF8File "$shim.cmd"

        Rename-ShimOnConflict $shim $Path
        @(
            '#!/bin/sh',
            "# $resolved_path",
            "python.exe `"$resolved_path`" $Arg `"$@`""
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    } else {
        Rename-ShimOnConflict "$shim.cmd" $Path
        $quoted_arg = if ($Arg.Count -gt 0) { $Arg | ForEach-Object { "`"$_`"" } }
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

        Rename-ShimOnConflict $shim $Path
        @(
            '#!/bin/sh',
            "# $resolved_path",
            "if [ `$WSL_INTEROP ]",
            'then',
            "  `"`$(wslpath -u '$resolved_path')`" $Arg `"$@`"",
            'else',
            "  `"`$(cygpath -u '$resolved_path')`" $Arg `"$@`"",
            'fi'
        ) -join "`n" | Out-UTF8File $shim -NoNewLine
    }
}

function Get-ShimTemplate {
    <#
    .SYNOPSIS
        Get the resolved path to the shim.exe template
    .PARAMETER Source
        A package name, or empty for the template shipped with Scoop.
        Omitted means the 'shim' setting decides.
    #>
    param(
        [AllowEmptyString()]
        [string] $Source
    )
    # omitted falls back to the setting
    if (!$PSBoundParameters.ContainsKey('Source')) { $Source = get_config SHIM }
    if (!$script:shimWarned) { $script:shimWarned = @{} }
    $key = "$Source"
    $warn = !$script:shimWarned.ContainsKey($key)
    $system = Get-SystemArchitecture
    $architecture = switch ($system) {
        'arm64' { 'arm64' }
        '64bit' { 'x64' }
        '32bit' { 'x86' }
        default { abort "Cannot tell which shim architecture to use (system reports '$system')." }
    }
    $builtin = "$PSScriptRoot\..\supporting\shims\$architecture\shim.exe"
    if ($Source) {
        foreach ($scope in $false, $true) {
            $template = "$(currentdir $Source $scope)\shim.exe"
            if (Test-Path -LiteralPath $template -PathType Leaf) {
                # shim package must provide a template for the correct architecture
                if ((Get-PEMachine $template) -eq (Get-PEMachine $builtin)) { return $template }
                if ($warn) {
                    warn "'$Source' provides a shim for another architecture - using the builtin one."
                    $script:shimWarned[$key] = $true
                }
                return $builtin
            }
        }
        if ($warn) {
            . "$PSScriptRoot\versions.ps1" # Select-CurrentVersion
            . "$PSScriptRoot\manifest.ps1" # parse_json
            if (installed $Source) {
                warn "'$Source' is not a shim package - falling back to the builtin one."
            } else {
                warn "'$Source' is not installed - falling back to the builtin one."
            }
            # TODO: delete this region together with the supporting\shims\<lane>\ directories,
            # whose .to_be_removed marker says the same. 'shim' used to name one of the three
            # lanes bundled in the tree, and those lanes ship as packages now.
            #region shim lanes that are no longer bundled
            $lanes = @{
                '71'      = 'scoop-shim-cpp'
                'kiennq'  = 'scoop-shim-kiennq'
                'scoopcs' = 'scoop-shim-cs'
            }
            if ($lanes.ContainsKey($Source)) {
                warn "'$Source' is no longer a builtin shim source, you can restore it by installing and configuring to '$($lanes[$Source])':"
                warn "    scoop install $($lanes[$Source])"
                warn "    scoop config shim $($lanes[$Source])"
            }
            #endregion shim lanes that are no longer bundled
            $script:shimWarned[$key] = $true
        }
    }
    $builtin
}

function Update-ShimInstance {
    <#
    .SYNOPSIS
        Update shim instances to use the given template
    .PARAMETER Template
        The resolved path to the shim.exe template
    .PARAMETER Instance
        List of shim instances to update, all shims will be updated if undefined
    .PARAMETER Global
        Flag to manipulate shims of global installs
    #>
    param(
        [string] $Template,
        [string[]] $Instance,
        [Nullable[bool]] $Global
    )
    if (!$Template) { $Template = Get-ShimTemplate }
    if ($null -eq $Global) {
        Update-ShimInstance $Template $Instance $false
        if (is_admin) { Update-ShimInstance $Template $Instance $true }
        return
    }
    $shimDir = shimdir $Global
    if (!(Test-Path -LiteralPath $Template) -or !(Test-Path -LiteralPath $shimDir)) { return }
    if ($Global -and !(is_admin)) { abort 'you need admin rights to update global shims' }

    $shims = Get-ChildItem -LiteralPath $shimDir -Filter '*.shim' -ErrorAction SilentlyContinue
    if ($Instance) {
        $shims = $shims | Where-Object { $_.BaseName -in $Instance }
    }

    $scope = if ($Global) { ' (global)' } else { '' }
    Write-Host "Updating shim(s)$scope$(if ($Instance) { " for $($Instance -join ', ')" })... " -NoNewline

    # System32 was once stored as Sysnative; nothing writes it any more, so a stored one is stale
    $sysnative = [System.IO.Path]::Combine($env:SystemRoot, 'Sysnative')
    $migrate = [System.Environment]::Is64BitOperatingSystem

    Get-ChildItem -LiteralPath $shimDir -Filter '*.oldshim' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $skipped = @()
    $shims | ForEach-Object {
        $name = $_.BaseName
        $dest = "$shimDir\$name.exe"
        if (!(Test-Path -LiteralPath $dest)) { return }
        $oldSubsystem = Get-PESubsystem $dest
        try {
            Copy-Item -LiteralPath $Template -Destination $dest -Force -ErrorAction Stop
        } catch {
            $aside = "$name.exe.$([DateTime]::UtcNow.Ticks).oldshim"
            try {
                Rename-Item -LiteralPath $dest -NewName $aside -Force -ErrorAction Stop
                Copy-Item -LiteralPath $Template -Destination $dest -ErrorAction Stop
            } catch {
                if (!(Test-Path -LiteralPath $dest) -and (Test-Path -LiteralPath "$shimDir\$aside")) {
                    Rename-Item -LiteralPath "$shimDir\$aside" -NewName "$name.exe" -Force -ErrorAction SilentlyContinue
                }
                $skipped += $name
                return
            }
        }
        # saved descriptions are restored later, so they migrate too
        if ($migrate) {
            $files = @(Get-Item -LiteralPath $_.FullName) + @(Get-ChildItem -LiteralPath $shimDir -Filter "$name.shim.*" -File -ErrorAction SilentlyContinue)
            foreach ($file in $files) {
                $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
                if ($lines[0] -like "*$sysnative\*") {
                    $stamp = $file.LastWriteTimeUtc
                    $lines[0] = $lines[0].Replace($sysnative, "$env:SystemRoot\System32")
                    ($lines -join "`r`n") | Out-UTF8File -FilePath $file.FullName -NoNewline
                    # the newest description is the one restored, so the rewrite must not move it to the front
                    [IO.File]::SetLastWriteTimeUtc($file.FullName, $stamp)
                }
            }
        }
        # the fresh copy lost the GUI flag; keep the old one when the target is unreadable
        $subsystem = Get-PESubsystem (Get-ShimTarget $_.FullName)
        if ($subsystem -lt 0) { $subsystem = $oldSubsystem }
        if ($subsystem -eq 2) {
            Set-PESubsystem $dest 2 | Out-Null
        }
    }

    Write-Host 'Done.' -ForegroundColor Green
    if ($skipped) {
        warn "Skipped $($skipped.Count) shim(s): $($skipped -join ', ')"
        warn "Run 'scoop shim update <shim(s)>' again to retry."
    }
}

# get target, name, arguments for shim
function Get-ShimDefinition($Item) {
    if ($Item -is [array]) { return $Item }
    return $Item, (strip_ext (fname $Item)), $null
}

function New-ShimFromManifest($Manifest, $Dir, $Global, $Arch) {
    $shims = @(arch_specific 'bin' $Manifest $Arch | Where-Object { $_ -ne $null })
    if (!$shims) { return }
    # the source is checked before the shims are created, so a bad one warns once
    $null = Get-ShimTemplate
    $shims | ForEach-Object {
        $target, $name, $arg = Get-ShimDefinition $_
        Write-Output "Creating shim for '$name'."

        if (Test-Path -LiteralPath "$Dir\$target" -PathType leaf) {
            $bin = "$Dir\$target"
        } elseif (Test-Path -LiteralPath $target -PathType leaf) {
            $bin = $target
        } elseif ($original_dir -and (Test-Path -LiteralPath "$original_dir\$target" -PathType leaf)) {
            $bin = "$original_dir\$target"
        } else {
            $bin = (Get-CommandLiteral $target @('Application', 'ExternalScript')).Source
        }
        if (!$bin) { abort "Can't shim '$target': File doesn't exist." }

        New-Shim $bin $Global $name (substitute $arg @{ '$dir' = $Dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir })
    }
}

# bucket manifests call these, and Invoke-HookScript replays the copy already saved on disk
function shim($path, $global, $name, $arg) {
    Show-DeprecatedWarning $MyInvocation 'New-Shim'
    New-Shim @PSBoundParameters
}

function rm_shim($name, $shimdir, $app) {
    Show-DeprecatedWarning $MyInvocation 'Remove-Shim'
    Remove-Shim @PSBoundParameters
}

function Remove-Shim($Name, $ShimDir, $App) {
    '', '.shim', '.cmd', '.ps1' | ForEach-Object {
        $shimPath = "$ShimDir\$Name$_"
        $altShimPath = "$shimPath.$App"
        if ($App -and (Test-Path -LiteralPath $altShimPath -PathType Leaf)) {
            Write-Output "Removing shim '$Name$_.$App'."
            Remove-Item -LiteralPath $altShimPath
        } elseif (Test-Path -LiteralPath $shimPath -PathType Leaf) {
            Write-Output "Removing shim '$Name$_'."
            Remove-Item -LiteralPath $shimPath
            $shimName = fname $shimPath
            $wrapperTokens = @('shim', 'exe', 'cmd', 'ps1', 'bat')
            # a saved file of another wrapper (tool.ps1.first) carries that wrapper after the name
            $oldShims = Get-ChildItem -LiteralPath $ShimDir -Filter "$shimName.*" -File |
                Where-Object { $_.Name.Substring($shimName.Length + 1).Split('.')[0] -notin $wrapperTokens }
            if ($null -eq $oldShims) {
                if (($_ -eq '.shim') -and (Test-Path -LiteralPath "$ShimDir\$Name.exe" -PathType Leaf)) {
                    Write-Output "Removing shim '$Name.exe'."
                    Remove-Item -LiteralPath "$ShimDir\$Name.exe"
                }
            } else {
                ($oldShims | Sort-Object -Property LastWriteTimeUtc)[-1] | Rename-Item -NewName { $shimName }
            }
        }
    }
}

function Remove-ShimFromManifest($App, $Manifest, $Global, $Arch) {
    $shims = @(arch_specific 'bin' $Manifest $Arch)

    $shims | Where-Object { $_ -ne $null } | ForEach-Object {
        $target, $name, $null = Get-ShimDefinition $_
        $ShimDir = shimdir $Global

        Remove-Shim $name $ShimDir $App
    }
}

function Get-ShimInfo($ShimPath) {
    $info = [Ordered]@{}
    $info.Name = strip_ext (fname $ShimPath)
    $info.Path = $ShimPath -replace 'shim$', 'exe'
    $info.Source = (Get-AppNameFromShim $ShimPath) -replace '^$', 'External'
    $info.Type = if ($ShimPath.EndsWith('.ps1')) { 'ExternalScript' } else { 'Application' }
    $shimName = fname $ShimPath
    $altShims = Get-ChildItem -LiteralPath (Split-Path $ShimPath -Parent) -File |
        Where-Object { $_.Name.StartsWith("$shimName.", [StringComparison]::OrdinalIgnoreCase) }
    if ($altShims) {
        $info.Alternatives = (@($info.Source) + ($altShims | ForEach-Object { $_.Extension.Remove(0, 1) } | Select-Object -Unique)) -join ' '
    }
    $info.IsGlobal = $ShimPath.StartsWith((shimdir $true))
    # the command is gone if the app was uninstalled without its shim; that is not an error
    $info.IsHidden = !((Get-CommandLiteral $info.Name).Path -eq $info.Path)
    [PSCustomObject]$info
}

function Get-ShimFile($ShimName, $Global) {
    '.shim', '.ps1' | ForEach-Object {
        $shimPath = Join-Path (shimdir $Global) "$ShimName$_"
        if (Test-Path -LiteralPath $shimPath) {
            return $shimPath
        }
    }
}
