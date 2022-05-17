# Usage: scoop shim <subcommand> [<shim_names>] [<command_path> [<args>...]] [-g(lobal)]
# Summary: Manipulate Scoop shims
# Help: Manipulate Scoop shims: add, rm, list, info, alter, etc.
#
# To add a custom shim, use the 'add' subcommand:
#
#     scoop shim add <shim_name> <command_path> [<args>...]
#
# To remove a shim, use the 'rm' subcommand (CAUTION: this could remove shims added by an app manifest):
#
#     scoop shim rm <shim_names>
#
# To list all shims or matching shims, use the 'list' subcommand:
#
#     scoop shim list [<shim_names>]
#
# To show a shim's information, use the 'info' subcommand:
#
#     scoop shim info <shim_name>
#
# To alternate a shim's target source, use the 'alter' subcommand:
#
#     scoop shim alter <shim_name>
#
# Options:
#   -g(lobal)       Add/Remove/Info/Alter global shim(s)
#                   (NOTICE: USING SINGLE DASH)
#                   (HINT: To pass arguments like '-g' or '-global' to the shim, use quotes)

param($SubCommand, $ShimName, [Switch]$global)

. "$PSScriptRoot\..\lib\install.ps1" # for rm_shim

if ($SubCommand -notin @('add', 'rm', 'list', 'info', 'alter')) {
    'ERROR: <subcommand> must be one of: add, rm, list, info, alter'
    my_usage
    exit 1
}

if ($SubCommand -ne 'list' -and !$ShimName) {
    "ERROR: <shim_name> must be specified for subcommand '$SubCommand'"
    my_usage
    exit 1
}

if ($Args) {
    switch ($SubCommand) {
        'add' {
            if ($Args[0] -like '-*') {
                "ERROR: <command_path> must be specified for subcommand 'add'"
                my_usage
                exit 1
            } else {
                if (($Args -join ' ') -match "^'(.*?)'\s*(.*?)$") {
                    $commandPath = $Matches[1]
                    $commandArgs = $Matches[2]
                } else {
                    $commandPath = $Args[0]
                    if ($Args.Length -gt 1) {
                        $commandArgs = $Args[1..($Args.Length - 1)]
                    }
                }
            }
        }
        'rm' {
            $ShimName = @($ShimName) + $Args
        }
        'list' {
            $ShimName = (@($ShimName) + $Args) -join '|'
        }
        default {
            # For 'info' and 'alter'
            "ERROR: Option $Args not recognized."
            my_usage
            exit 1
        }
    }
}

if (-not (Get-FormatData ScoopShims)) {
    Update-FormatData "$PSScriptRoot\..\supporting\formats\ScoopTypes.Format.ps1xml"
}

$localShimDir = shimdir $false
$globalShimDir = shimdir $true

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
        if (Test-Path $shimPath) {
            return $shimPath
        }
    }
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
        $shimTarget | Convert-Path
    }
}

switch ($SubCommand) {
    'add' {
        if ($commandPath -notmatch '[\\/]') {
            $shortPath = $commandPath
            $commandPath = Get-ShimTarget (Get-ShimPath $shortPath $global)
            if (!$commandPath) {
                $exCommand = Get-Command $shortPath -ErrorAction SilentlyContinue
                if ($exCommand -and $exCommand.CommandType -eq 'Application') {
                    $commandPath = $exCommand.Path
                } # TODO - add support for more command types: Alias, Cmdlet, ExternalScript, Filter, Function, Script, and Workflow
            }
        }
        if ($commandPath -and (Test-Path $commandPath)) {
            Write-Host "Adding $(if ($global) { 'global' } else { 'local' }) shim " -NoNewline
            Write-Host $shimName -ForegroundColor Cyan -NoNewline
            Write-Host '...'
            shim $commandPath $global $shimName $commandArgs
        } else {
            abort "ERROR: '$($Args[0])' does not exist" 3
        }
    }
    'rm' {
        $failed = @()
        $ShimName | ForEach-Object {
            if (Get-ShimPath $_ $global) {
                rm_shim $_ (shimdir $global)
            } else {
                $failed += $_
            }
        }
        if ($failed) {
            Write-Host 'Shims not found: ' -NoNewline
            Write-Host $failed -ForegroundColor Cyan
            exit 3
        }
    }
    'list' {
        $shims = Get-ChildItem -Path $localShimDir -Recurse -Include '*.shim', '*.ps1' |
            Where-Object { !$ShimName -or ($_.BaseName -match $ShimName) } |
            Select-Object -ExpandProperty FullName
        if (Test-Path $globalShimDir) {
            $shims += Get-ChildItem -Path $globalShimDir -Recurse -Include '*.shim', '*.ps1' |
                Where-Object { !$ShimName -or ($_.BaseName -match $ShimName) } |
                Select-Object -ExpandProperty FullName
        }
        $shims.ForEach({ Get-ShimInfo $_ }) | Add-Member -TypeName 'ScoopShims' -PassThru
    }
    'info' {
        $shimPath = Get-ShimPath $ShimName $global
        if ($shimPath) {
            Get-ShimInfo $shimPath
        } else {
            Write-Host "$(if ($global) { 'Global' } else { 'Local' }) shim not found: " -NoNewline
            Write-Host $ShimName -ForegroundColor Cyan
            if (Get-ShimPath $ShimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim info $ShimName$(if (!$global) { ' -global' })' to show its info"
                exit 2
            }
            exit 3
        }
    }
    'alter' {
        $shimPath = Get-ShimPath $ShimName $global
        if ($shimPath) {
            $shimInfo = Get-ShimInfo $shimPath
            if ($null -eq $shimInfo.Alternatives) {
                Write-Host 'No alternatives of ' -NoNewline
                Write-Host $ShimName -ForegroundColor Cyan -NoNewline
                Write-Host ' found.'
                exit 2
            }
            $shimInfo.Alternatives = $shimInfo.Alternatives.Split(' ')
            [System.Management.Automation.Host.ChoiceDescription[]]$altApps = 1..$shimInfo.Alternatives.Length | ForEach-Object {
                New-Object System.Management.Automation.Host.ChoiceDescription "&$($_)`b$($shimInfo.Alternatives[$_ - 1])", "Sets '$ShimName' shim from $($shimInfo.Alternatives[$_ - 1])."
            }
            $selected = $Host.UI.PromptForChoice("Alternatives of '$ShimName' command", "Please choose one that provides '$ShimName' as default:", $altApps, 0)
            if ($selected -eq 0) {
                Write-Host $ShimName -ForegroundColor Cyan -NoNewline
                Write-Host ' is already from ' -NoNewline
                Write-Host $shimInfo.Source -ForegroundColor DarkYellow -NoNewline
                Write-Host ', nothing changed.'
            } else {
                $newApp = $shimInfo.Alternatives[$selected]
                Write-Host 'Use ' -NoNewline
                Write-Host $ShimName -ForegroundColor Cyan -NoNewline
                Write-Host ' from ' -NoNewline
                Write-Host $newApp -ForegroundColor DarkYellow -NoNewline
                Write-Host ' as default...' -NoNewline
                $pathNoExt = strip_ext $shimPath
                '', '.shim', '.cmd', '.ps1' | ForEach-Object {
                    $oldShimPath = "$pathNoExt$_"
                    $newShimPath = "$oldShimPath.$newApp"
                    if (Test-Path -Path $oldShimPath -PathType Leaf) {
                        Rename-Item -Path $oldShimPath -NewName "$oldShimPath.$($shimInfo.Source)" -Force
                        if (Test-Path -Path $newShimPath -PathType Leaf) {
                            Rename-Item -Path $newShimPath -NewName $oldShimPath -Force
                        }
                    }
                }
                Write-Host 'done.'
            }
        } else {
            Write-Host "$(if ($global) { 'Global' } else { 'Local' }) shim not found: " -NoNewline
            Write-Host $ShimName -ForegroundColor Cyan
            if (Get-ShimPath $ShimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim alter $ShimName$(if (!$global) { ' -global' })' to alternate its source"
                exit 2
            }
            exit 3
        }
    }
}

exit 0
