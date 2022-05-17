#Requires -Version 5
if ($Args.Count -gt 0) {
    [string]$SubCommand = $Args[0]
    [string[]]$arguments = $Args | Select-Object -Skip 1
}
Set-StrictMode -Off

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\commands.ps1"
. "$PSScriptRoot\..\lib\help.ps1"

# for aliases where there's a local function, re-alias so the function takes precedence
$aliases = Get-Alias | Where-Object { $_.Options -notmatch 'ReadOnly|AllScope' } | ForEach-Object { $_.Name }
Get-ChildItem Function: | Where-Object -Property Name -In -Value $aliases | ForEach-Object {
    Set-Alias -Name $_.Name -Value Local:$($_.Name) -Scope Script
}

switch ($SubCommand) {
    ({ $SubCommand -in @($null, '-h', '--help', '/?') }) {
        exec 'help'
    }
    ({ $SubCommand -in @('-v', '--version') }) {
        Write-Host 'Current Scoop version:'
        if ((Test-CommandAvailable git) -and (Test-Path "$PSScriptRoot\..\.git") -and (get_config SCOOP_BRANCH 'master') -ne 'master') {
            Invoke-Expression "git -C '$PSScriptRoot\..' --no-pager log --oneline HEAD -n 1"
        } else {
            $version = Select-String -Pattern '^## \[(v[\d.]+)\].*?([\d-]+)$' -Path "$PSScriptRoot\..\CHANGELOG.md"
            Write-Host $version.Matches.Groups[1].Value -ForegroundColor Cyan -NoNewline
            Write-Host " - Released at $($version.Matches.Groups[2].Value)"
        }
        Write-Host ''

        Get-LocalBucket | ForEach-Object {
            $bucketLoc = Find-BucketDirectory $_ -Root
            if ((Test-Path (Join-Path $bucketLoc '.git')) -and (Test-CommandAvailable git)) {
                Write-Host "'$_' bucket:"
                Invoke-Expression "git -C '$bucketLoc' --no-pager log --oneline HEAD -n 1"
                Write-Host ''
            }
        }
    }
    ({ $SubCommand -in (commands) }) {
        if ($arguments.Count -gt 0 -and $arguments[0] -in @('-h', '--help', '/?')) {
            exec 'help' @($SubCommand)
        } else {
            exec $SubCommand $arguments
        }
    }
    default {
        "scoop: '$SubCommand' isn't a scoop command. See 'scoop help'."
        exit 1
    }
}
