# Usage: scoop shim [<subcommand>] <shim_names> [<command_path> [<args>...]]
# Summary: Manipulate Scoop shims
# Help: Manipulate Scoop shims: add, remove, list, info, alter, etc.
#
# To add a costom shim, use the 'add' subcommand:
#
#     scoop shim add <shim_name> <command_path> [<args>...]
#
# To remove a shim, use the 'remove' subcommand (CAUTION: this could remove shims added by app manifest):
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
#   -g, --global       Add/Remove/Info global shim(s)

param($SubCommand, $ShimName)

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\help.ps1"
. "$PSScriptRoot\..\lib\getopt.ps1" # for getopt
. "$PSScriptRoot\..\lib\install.ps1" # for rm_shim

$opt, $addArgs, $err = getopt $Args 'g' 'global'
if ($err) { "scoop shim: $err"; exit 1 }
$global = $opt.g -or $opt.global
$globalTag = if ($global) { 'global' } else { 'local' }

if ($SubCommand -notin @('add', 'remove', 'list', 'info', 'alter')) {
    'ERROR: <subcommand> must be one of: add, remove, list, info, alter'
    my_usage
    exit 1
}

if (!$ShimName -and $SubCommand -ne 'list') {
    'ERROR: <shim_name> must be specified'
    my_usage
    exit 1
}

if ($SubCommand -eq 'add' -and $addArgs.Length -eq 0) {
    'ERROR: <command_path> must be specified'
    my_usage
    exit 1
}

if (-not (Get-FormatData ScoopShim)) {
    Update-FormatData "$PSScriptRoot\..\supporting\formats\ScoopTypes.Format.ps1xml"
}

$localShimDir = shimdir $false
$globalShimDir = shimdir $true

function Get-ShimInfo($ShimPath) {
    $info = @{ PSTypeName = 'ScoopShim' }
    $info.Name = strip_ext (fname $ShimPath)
    $info.Path = $ShimPath -replace 'shim$', 'exe'
    $info.Source = get_app_name_from_shim $ShimPath
    $info.Type = if ($ShimPath.EndsWith('.shim')) { 'Application' } elseif ($ShimPath.EndsWith('.cmd')) { 'Script' } else { 'Unknown' }
    $altShims = Get-Item -Path "$ShimPath.*" -Exclude '*.shim', '*.cmd', '*.ps1'
    if ($altShims) {
        $info.Alternatives = @($info.Source) + ($altShims | ForEach-Object { $_.Extension.Remove(0, 1) } | Select-Object -Unique)
    }
    $info.IsGlobal = if ($ShimPath.StartsWith("$globalShimDir")) { $true } else { $false }
    $info.IsHidden = if ((Get-Command -Name $info.Name).Path -eq $info.Path) { $false } else { $true }
    [PSCustomObject]$info
}

function Get-ShimPath($ShimName, $Global) {
    '.shim', '.cmd' | ForEach-Object {
        $shimPath = Join-Path (shimdir $Global) "$ShimName$_"
        if (Test-Path -Path $shimPath) {
            return $shimPath
        }
    }
}

function Get-ShimTarget($ShimPath) {
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

switch ($SubCommand) {
    'add' {
        if ($addArgs[0] -match '[\\/]') {
            $commandPath = $addArgs[0]
        } else {
            $commandPath = Get-ShimTarget (Get-ShimPath $addArgs[0] $global)
        }
        if ($commandPath -and (Test-Path $commandPath)) {
            Write-Host "Adding $globalTag shim " -NoNewline
            Write-Host $ShimName -ForegroundColor Cyan -NoNewline
            Write-Host ' ... ' -NoNewline
            shim $commandPath $global $ShimName $(if ($addArgs.Length -gt 1) { $addArgs[1..($addArgs.Length - 1)] })
            Write-Host 'Done'
        } else {
            "ERROR: '$($addArgs[0])' does not exist"
            exit 1
        }
    }
    'remove' {
        @($ShimName) + $addArgs | ForEach-Object {
            if (Get-ShimPath $_ $global) {
                rm_shim $_ (shimdir $global)
            } else {
                Write-Host "Shims not found: $_"
            }
        }
    }
    'list' {
        $shims = Get-ChildItem -Path $localShimDir -Recurse -Include '*.shim', '*.cmd' |
            Where-Object { !$ShimName -or ($_.BaseName -match $ShimName) } |
            Select-Object -ExpandProperty FullName
        if (Test-Path $globalShimDir) {
            $shims += Get-ChildItem -Path $globalShimDir -Recurse -Include '*.shim', '*.cmd' |
                Where-Object { !$ShimName -or ($_.BaseName -match $ShimName) } |
                Select-Object -ExpandProperty FullName
        }
        $shims.ForEach({ Get-ShimInfo $_ })
    }
    'info' {
        $shimPath = Get-ShimPath $ShimName $global
        if ($shimPath) {
            $shim = Get-ShimInfo $shimPath
            Write-Host "Shim Name: $($shim.Name)"
            Write-Host "Shim Path: $($shim.Path)"
            Write-Host "Shim Source: $($shim.Source)"
            Write-Host "Shim Type: $($shim.Type)"
            Write-Host "Is Shim Global Installed: $($shim.IsGlobal)"
            if ($shim.Alternatives) {
                Write-Host "Alternative Shim Sources: $($shim.Alternatives)"
            }
            Write-Host "Is Shim Accessible: $(!$shim.IsHidden)"
        } else {
            Write-Host "$(if ($global) { 'Global' } else { 'Local' }) shim not found: $ShimName"
            if (Get-ShimPath $ShimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim info $ShimName$(if (!$global) { ' -global' })' to show its info"
                exit 2
            }
            exit 1
        }
    }
    'alter' {
        & "$PSScriptRoot\scoop-alter.ps1" $ShimName
    }
}

exit 0
