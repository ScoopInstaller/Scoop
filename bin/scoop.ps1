#requires -v 3
param($cmd)

set-strictmode -off

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. (relpath '..\lib\commands')

reset_aliases

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
