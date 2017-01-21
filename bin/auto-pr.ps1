. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\json.ps1"

Write-Host -f DarkCyan "Pulling current upstream master..."
hub checkout master *> $null
hub pull upstream master
hub push origin master
. "$psscriptroot\checkver.ps1" * -u

hub diff --name-only | % {
    $manifest = $_
    if($manifest.EndsWith('.json')) {

        $app = ([System.IO.Path]::GetFileNameWithoutExtension($manifest))
        $json = parse_json $manifest
        if($json.version) {
            $version = $json.version
            $homepage = $json.homepage
            $branch = "$app-$version"
            hub checkout master *> $null
            hub rev-parse --verify $branch *> $null
            if($LASTEXITCODE -gt 0) {
                Write-Host -f DarkCyan "Creating update $app ($version) ..."
                hub checkout -b $branch *> $null
                hub add $manifest
                hub commit -m "Update $app to version $version"
                Write-Host -f DarkCyan "Pushing update $app ($version) ..."
                hub push origin $branch
                if($LASTEXITCODE -gt 0) {
                    Write-Host -f DarkRed "Push failed! (hub push origin $branch)"
                } else {
                    Write-Host -f DarkCyan "Pull-Request update $app ($version) ..."
                    hub pull-request -m "Update $app to version $version`n`nHello lovely humans,`n
a new version of [$app]($homepage) is available.
<table>
<tr><th align=left>State</th><td>Update :rocket:</td></tr>
<tr><th align=left>New version</td><td>$version</td></tr>
</table>" -b 'lukesampson/scoop:master' -h $branch
                    if($LASTEXITCODE -gt 0) {
                        Write-Host -f DarkRed "Pull Request failed! (hub pull-request -m 'update $app to version $version' -b 'lukesampson/scoop:master' -h $branch)"
                    }
                }
            } else {
                Write-Host -f DarkRed "Skipping update $app ($version) ..."
            }
        }
    }
}

# return to master branch and remove unstaged files
hub checkout -f master *> $null
