# Usage: scoop alter <command>
# Summary: Maintain shims determining default commands (similar to '(update-)alternatives' on Linux)
# Help: Display and maintain alternatives of a shimmed command installed with Scoop (similar to '(update-)alternatives' on Linux)

param($command)
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

reset_aliases

if (!$command) { 'ERROR: <command> missing'; my_usage; exit 1 }

try {
    $gcm = (Get-Command "$command" -ErrorAction Stop).Path.ToString()
} catch {
    abort "'$command' not found" 3
}

$path = $gcm -replace '\.exe$', '.shim'
$userShimPath = "$(Resolve-Path $(shimdir $false))"
$globalShimPath = fullpath (shimdir $true) # don't resolve: may not exist

if ($path -like "$userShimPath*" -or $path -like "$globalShimPath*") {
    $altShims = Get-Item -Path "$path.*" -Exclude '*.shim', '*.cmd', '*.ps1'
    if ($null -eq $altShims) {
        Write-Host "No alternatives of '$command' found."
        exit 0
    }
    $app = get_app_name_from_shim $path
    $apps = @($app) + ($altShims | ForEach-Object { $_.Extension.Remove(0, 1) } | Select-Object -Unique)
    [System.Management.Automation.Host.ChoiceDescription[]]$altApps = 1..$apps.Length | ForEach-Object {
        New-Object System.Management.Automation.Host.ChoiceDescription "&$($_)`b$($apps[$_ - 1])", "Sets '$command' shim from $($apps[$_ - 1])."
    }
    $selected = $Host.UI.PromptForChoice("Alternatives of '$command' command", "Please choose one that provides '$command' as default:", $altApps, 0)
    if ($selected -eq 0) {
        Write-Host "'$command' is already from '$app', nothing changed."
        exit 0
    } else {
        $newApp = $apps[$selected]
        Write-Host "Use '$command' from '$newApp' as default..." -NoNewline
        $pathNoExt = strip_ext $path
        '', '.shim', '.cmd', '.ps1' | ForEach-Object {
            $shimPath = "$pathNoExt$_"
            $newShimPath = "$shimPath.$newApp"
            if (Test-Path -Path $shimPath -PathType Leaf) {
                Rename-Item -Path $shimPath -NewName "$shimPath.$app" -Force
                if (Test-Path -Path $newShimPath -PathType Leaf) {
                    Rename-Item -Path $newShimPath -NewName $shimPath -Force
                }
            }
        }
        Write-Host 'done.'
    }
} else {
    Write-Host 'Not a scoop shim.'
    Write-Host "Command path is: $gcm"
    exit 2
}

exit 0
