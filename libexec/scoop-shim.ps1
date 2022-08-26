# Usage: scoop shim <subcommand> [options] [args]
# Summary: Manipulate Scoop shims
# Help: Available subcommands: add, rm, list, info, alter.
#
# To add a custom shim, use the 'add' subcommand:
#
#     scoop shim add <shim_name> <command_path> [<args>...]
#
# To remove shims, use the 'rm' subcommand: (CAUTION: this could remove shims added by an app manifest)
#
#     scoop shim rm <shim_name>...
#
# To list all shims or matching shims, use the 'list' subcommand:
#
#     scoop shim list [<pattern>...]
#
# To show a shim's information, use the 'info' subcommand:
#
#     scoop shim info <shim_name>
#
# To alternate a shim's target source, use the 'alter' subcommand:
#
#     scoop shim alter <shim_name>
#
# Options for subcommand add, rm, info, alter:
#   -g, --global       Manipulate global shim(s)
#
# HINT: The FIRST double-hyphen '--', if any, will be treated as the POSIX-style command option terminator
# and will NOT be included in arguments, so if you want to pass arguments like '-g' or '--global' to
# the shim, put them after a '--'. Note that in PowerShell, you must use a QUOTED '--', e.g.,
#
#     scoop shim add myapp 'D:\path\myapp.exe' '--' arg --global

param($SubCommand)

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\install.ps1" # for rm_shim

if ($SubCommand -notin @('add', 'rm', 'list', 'info', 'alter')) {
    if (!$SubCommand) {
        error '<subcommand> missing'
    } else {
        error "'$SubCommand' is not one of available subcommands: add, rm, list, info, alter"
    }
    my_usage
    exit 1
}

$opt, $Arguments, $err = getopt $args 'g' 'global'
if ($err) { "scoop shim: $err"; exit 1 }

$global = $opt.g -or $opt.global

if ($SubCommand -ne 'list' -and $Arguments.Length -eq 0) {
    error "<shim_name> must be specified for subcommand '$SubCommand'"
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

switch ($SubCommand) {
    'add' {
        if ($Arguments.Length -lt 2 -or $Arguments[1] -eq '') {
            error "<command_path> must be specified for subcommand 'add'"
            my_usage
            exit 1
        }
        $shimName = $Arguments[0]
        $commandPath = $Arguments[1]
        if ($Arguments.Length -gt 2) {
            $commandArgs = $Arguments[2..($Arguments.Length - 1)]
        }
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
            Write-Host "ERROR: Command path does not exist: " -ForegroundColor Red -NoNewline
            Write-Host $($Arguments[1]) -ForegroundColor Cyan
            exit 3
        }
    }
    'rm' {
        $failed = @()
        $Arguments | ForEach-Object {
            if (Get-ShimPath $_ $global) {
                rm_shim $_ (shimdir $global)
            } else {
                $failed += $_
            }
        }
        if ($failed) {
            $failed | ForEach-Object {
                Write-Host "ERROR: $(if ($global) { 'Global' } else {'Local' }) shim not found: " -ForegroundColor Red -NoNewline
                Write-Host $_ -ForegroundColor Cyan
            }
            exit 3
        }
    }
    'list' {
        # Validate all given patterns before matching.
        $Arguments | ForEach-Object {
            try {
                $pattern = $_
                [regex]::new($pattern)
            } catch {
                Write-Host "ERROR: Invalid pattern: " -ForegroundColor Red -NoNewline
                Write-Host $pattern -ForegroundColor Magenta
                exit 1
            }
        }
        $pattern = $Arguments -join '|'
        $shims = Get-ChildItem -Path $localShimDir -Recurse -Include '*.shim', '*.ps1' |
        Where-Object { !$pattern -or ($_.BaseName -match $pattern) } |
        Select-Object -ExpandProperty FullName
        if (Test-Path $globalShimDir) {
            $shims += Get-ChildItem -Path $globalShimDir -Recurse -Include '*.shim', '*.ps1' |
            Where-Object { !$pattern -or ($_.BaseName -match $pattern) } |
            Select-Object -ExpandProperty FullName
        }
        $shims.ForEach({ Get-ShimInfo $_ }) | Add-Member -TypeName 'ScoopShims' -PassThru
    }
    'info' {
        $shimName = $Arguments[0]
        $shimPath = Get-ShimPath $shimName $global
        if ($shimPath) {
            Get-ShimInfo $shimPath
        } else {
            Write-Host "ERROR: $(if ($global) { 'Global' } else { 'Local' }) shim not found: " -ForegroundColor Red -NoNewline
            Write-Host $shimName -ForegroundColor Cyan
            if (Get-ShimPath $shimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim info $(if (!$global) { '--global ' })$shimName' to show its info"
                exit 2
            }
            exit 3
        }
    }
    'alter' {
        $shimName = $Arguments[0]
        $shimPath = Get-ShimPath $shimName $global
        if ($shimPath) {
            $shimInfo = Get-ShimInfo $shimPath
            if ($null -eq $shimInfo.Alternatives) {
                Write-Host 'ERROR: No alternatives of ' -ForegroundColor Red -NoNewline
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
                Write-Host 'INFO: ' -ForegroundColor Blue -NoNewline
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
            Write-Host "ERROR: $(if ($global) { 'Global' } else { 'Local' }) shim not found: " -ForegroundColor Red -NoNewline
            Write-Host $shimName -ForegroundColor Cyan
            if (Get-ShimPath $shimName (!$global)) {
                Write-Host "But a $(if ($global) { 'local' } else {'global' }) shim exists, " -NoNewline
                Write-Host "run 'scoop shim alter $(if (!$global) { '--global ' })$shimName' to alternate its source"
                exit 2
            }
            exit 3
        }
    }
}

exit 0
