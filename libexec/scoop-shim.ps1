# Usage: scoop shim <subcommand> [<shim_names>] [<command_path>]
# Summary: Manipulate Scoop shims
# Help: Manipulate Scoop shims: add, remove/rm, list, info, alter, etc.
#
# To add a costom shim, use the 'add' subcommand:
#
#     scoop shim add <shim_name> <command_path>
#
# To remove a shim, use the 'remove' or 'rm' subcommand (CAUTION: this could remove shims added by app manifest):
#
#     scoop shim remove <shim_names>
#
# To list all shims or a matching shim, use the 'list' subcommand:
#
#     scoop shim list [<shim_name>]
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
#   -g, --global       Add/Remove/Info/Alter global shim(s)

param($SubCommand)

. "$PSScriptRoot\..\lib\help.ps1"
. "$PSScriptRoot\..\lib\getopt.ps1" # for getopt
. "$PSScriptRoot\..\lib\install.ps1" # for rm_shim

$opt, $addArgs, $err = getopt $Args 'g' 'global'
if ($err) { abort "scoop shim: $err" 1 }
$global = $opt.g -or $opt.global
$globalTag = if ($global) { 'global' } else { 'local' }

$shimName = $addArgs[0]

if ($SubCommand -notin @('add', 'remove', 'rm', 'list', 'info', 'alter')) {
    'ERROR: <subcommand> must be one of: add, remove/rm, list, info, alter'
    my_usage
    exit 1
}

if (!$shimName -and $SubCommand -ne 'list') {
    "ERROR: <shim_name> must be specified for subcommand '$SubCommand'"
    my_usage
    exit 1
}

if ($SubCommand -eq 'add' -and $null -eq $addArgs[1]) {
    "ERROR: <command_path> must be specified for subcommand 'add'"
    my_usage
    exit 1
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
    $info.Source = get_app_name_from_shim $ShimPath
    $info.Type = if ($ShimPath.EndsWith('.shim')) { 'Application' } elseif ($ShimPath.EndsWith('.cmd')) { 'Script' } else { 'Unknown' }
    $altShims = Get-Item -Path "$ShimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
    if ($altShims) {
        $info.Alternatives = (@($info.Source) + ($altShims | ForEach-Object { $_.Extension.Remove(0, 1) } | Select-Object -Unique)) -join ' '
    }
    $info.IsGlobal = $ShimPath.StartsWith("$globalShimDir")
    $info.IsHidden = !((Get-Command -Name $info.Name).Path -eq $info.Path)
    [PSCustomObject]$info
}

function Get-ShimPath($shimName, $Global) {
    '.shim', '.cmd' | ForEach-Object {
        $shimPath = Join-Path (shimdir $Global) "$shimName$_"
        if (Test-Path $shimPath) {
            return $shimPath
        }
    }
}

function Get-ShimTarget($ShimPath) {
    if ($ShimPath) {
        $shimTarget = if ($ShimPath.EndsWith('.shim')) {
            (Get-Content -Path $ShimPath | Select-Object -First 1).Replace('path = ', '')
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
        $commandPath = $addArgs[1]
        if ($commandPath -match "^[`"'](.*?)[`"']\s*(.*)$") {
            $commandPath = $Matches[1]
            $commandArgs = $Matches[2]
        } elseif ($commandPath -match '^([^\s]*)\s*(.*)$') {
            $commandPath = $Matches[1]
            $commandArgs = $Matches[2]
        }
        if ($commandPath -notmatch '[\\/]') {
            $commandPath = Get-ShimTarget (Get-ShimPath $commandPath $global)
        }
        if ($commandPath -and (Test-Path $commandPath)) {
            Write-Host "Adding $globalTag shim " -NoNewline
            Write-Host $shimName -ForegroundColor Cyan -NoNewline
            Write-Host ' ... ' -NoNewline
            shim $commandPath $global $shimName $commandArgs
            Write-Host 'Done'
        } else {
            abort "ERROR: '$($addArgs[1])' does not exist" 3
        }
    }
    { $_ -in 'remove', 'rm' } {
        $failed = @()
        $addArgs | ForEach-Object {
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
        $shims = Get-ChildItem -Path $localShimDir -Recurse -Include '*.shim', '*.cmd' |
            Where-Object { !$shimName -or ($_.BaseName -match $shimName) } |
            Select-Object -ExpandProperty FullName
        if (Test-Path $globalShimDir) {
            $shims += Get-ChildItem -Path $globalShimDir -Recurse -Include '*.shim', '*.cmd' |
                Where-Object { !$shimName -or ($_.BaseName -match $shimName) } |
                Select-Object -ExpandProperty FullName
        }
        $shims.ForEach({ Get-ShimInfo $_ }) | Add-Member -TypeName 'ScoopShims' -PassThru
    }
    'info' {
        $shimPath = Get-ShimPath $shimName $global
        if ($shimPath) {
            Get-ShimInfo $shimPath
        } else {
            Write-Host "$(if ($global) { 'Global' } else { 'Local' }) shim not found: " -NoNewline
            Write-Host $shimName -ForegroundColor Cyan
            if (Get-ShimPath $shimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim info $shimName$(if (!$global) { ' -global' })' to show its info"
                exit 2
            }
            exit 3
        }
    }
    'alter' {
        $shimPath = Get-ShimPath $shimName $global
        if ($shimPath) {
            $shimInfo = Get-ShimInfo $shimPath
            if ($null -eq $shimInfo.Alternatives) {
                Write-Host 'No alternatives of ' -NoNewline
                Write-Host $shimName -ForegroundColor Cyan -NoNewline
                Write-Host ' found.'
                exit 2
            }
            $shimInfo.Alternatives = $shimInfo.Alternatives.Split(' ')
            [System.Management.Automation.Host.ChoiceDescription[]]$altApps = 1..$shimInfo.Alternatives.Length | ForEach-Object {
                New-Object System.Management.Automation.Host.ChoiceDescription "&$($_)`b$($shimInfo.Alternatives[$_ - 1])", "Sets '$shimName' shim from $($shimInfo.Alternatives[$_ - 1])."
            }
            $selected = $Host.UI.PromptForChoice("Alternatives of '$shimName' command", "Please choose one that provides '$shimName' as default:", $altApps, 0)
            if ($selected -eq 0) {
                Write-Host $shimName -ForegroundColor Cyan -NoNewline
                Write-Host ' is already from ' -NoNewline
                Write-Host $shimInfo.Source -ForegroundColor DarkYellow -NoNewline
                Write-Host ', nothing changed.'
            } else {
                $newApp = $shimInfo.Alternatives[$selected]
                Write-Host 'Use ' -NoNewline
                Write-Host $shimName -ForegroundColor Cyan -NoNewline
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
            Write-Host $shimName -ForegroundColor Cyan
            if (Get-ShimPath $shimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim alter $shimName$(if (!$global) { ' -global' })' to alternate its source"
                exit 2
            }
            exit 3
        }
    }
}

exit 0
