#Requires -Version 5
param($cmd)

Set-StrictMode -off

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\commands.ps1"
# for aliases where there's a local function, re-alias so the function takes precedence
$aliases = Get-Alias | Where-Object { $_.Options -notmatch 'ReadOnly|AllScope' } | ForEach-Object { $_.Name }
Get-ChildItem Function: | Where-Object -Property Name -In -Value $aliases | ForEach-Object {
    Set-Alias -Name $_.Name -Value Local:$($_.Name) -Scope Script
}

$commands = commands
if ('--version' -contains $cmd -or (!$cmd -and '-v' -contains $args)) {
    Write-Host "Current Scoop version:"
    Invoke-Expression "git -C '$(versiondir 'scoop' 'current')' --no-pager log --oneline HEAD -n 1"
    Write-Host ""

    Get-LocalBucket | ForEach-Object {
        $bucketLoc =  Find-BucketDirectory $_ -Root
        if(Test-Path (Join-Path $bucketLoc '.git')) {
            Write-Host "'$_' bucket:"
            Invoke-Expression "git -C '$bucketLoc' --no-pager log --oneline HEAD -n 1"
            Write-Host ""
        }
    }
}
elseif (@($null, '--help', '/?') -contains $cmd -or $args[0] -contains '-h') { exec 'help' $args }
elseif ($commands -contains $cmd) { exec $cmd $args }
else { "scoop: '$cmd' isn't a scoop command. See 'scoop help'."; exit 1 }
