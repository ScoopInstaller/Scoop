# Usage: .\bin\auto-pr.ps1 [options]
# Summary: Updates manifests and pushes them or creates pull-requests
# Help: Updates manifests and pushes them to directly the master branch or creates pull-requests for upstream
#
# Options:
#   -p, --push                push updates directly to 'origin master'
#   -r, --request             create pull-requests on 'upstream master' for each update
#   -u, --upstream <upstream> upstream repository with target branch
#                               only used if -r is set (default: lukesampson/scoop:master)

param(
    [String]$upstream = "lukesampson/scoop:master",
    [String]$dir,
    [Switch]$push = $false,
    [Switch]$request = $false,
    [Switch]$help = $false
)

if(!$dir) { $dir = "$psscriptroot\.." }
$dir = resolve-path $dir

. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\json.ps1"

if (!(scoop which hub)) {
    Write-Host -f yellow "Please install hub (scoop install hub)"
    exit 1
}

if ((!$push -and !$request) -or $help) {
    Write-Host ""
    Write-Host "Usage: auto-pr.ps1 [OPTION]"
    Write-Host ""
    Write-Host "Mandatory options:"
    Write-Host "  -p,  -push                       push updates directly to 'origin master'"
    Write-Host "  -r,  -request                    create pull-requests on 'upstream master' for each update"
    Write-Host ""
    Write-Host "Optional options:"
    Write-Host "  -u,  -upstream                   upstream repository with target branch"
    Write-Host "                                     only used if -r is set (default: lukesampson/scoop:master)"
    Write-Host "  -h,  -help"
    Write-Host ""
    exit 0
}

if(!($upstream -match "^(.*)\/(.*):(.*)$")) {
    Write-Host -f DarkRed "Upstream must have this format: <user>/<repo>:<branch>"
    exit 1
}

function execute($cmd) {
    Write-Host -f Green $cmd
    $output = iex $cmd

    if($LASTEXITCODE -gt 0) {
        Write-Host -f Red "^^^ Error! See above ^^^ (last command: $cmd)"
        exit 1
    }
    return $output
}

function pull_requests($json, [String]$app, [String]$upstream, [String]$manifest)
{
    $version = $json.version
    $homepage = $json.homepage
    $branch = "manifest/$app-$version"

    execute "hub checkout master"
    execute "hub rev-parse --verify $branch"

    if($LASTEXITCODE -eq 0) {
        Write-Host -f Yellow "Skipping update $app ($version) ..."
        return
    }

    Write-Host -f DarkCyan "Creating update $app ($version) ..."
    execute "hub checkout -b $branch"
    execute "hub add $manifest"
    execute "hub commit -m 'Update $app to version $version'"
    Write-Host -f DarkCyan "Pushing update $app ($version) ..."
    execute "hub push origin $branch"

    if($LASTEXITCODE -gt 0) {
        Write-Host -f DarkRed "Push failed! (hub push origin $branch)"
        execute "hub reset"
        return
    }

    Write-Host -f DarkCyan "Pull-Request update $app ($version) ..."
    Write-Host -f green "hub pull-request -m '<msg>' -b '$upstream' -h $branch"
    hub pull-request -m "Update $app to version $version`n`nHello lovely humans,`n
a new version of [$app]($homepage) is available.
<table>
<tr><th align=left>State</th><td>Update :rocket:</td></tr>
<tr><th align=left>New version</td><td>$version</td></tr>
</table>" -b '$upstream' -h $branch
    if($LASTEXITCODE -gt 0) {
        Write-Host -f DarkRed "Pull Request failed! (hub pull-request -m 'update $app to version $version' -b '$upstream' -h $branch)"
        execute "hub reset"
        exit 1
    }
}

Write-Host -f DarkCyan "Updating ..."
if($push -eq $true) {
    execute("hub pull origin master")
    execute "hub checkout master"
} else {
    execute("hub pull upstream master")
    execute("hub push origin master")
}

. "$dir\bin\checkver.ps1" * -update

hub diff --name-only | % {
    $manifest = $_
    if(!$manifest.EndsWith(".json")) {
        return
    }

    $app = ([System.IO.Path]::GetFileNameWithoutExtension($manifest))
    $json = parse_json $manifest
    if(!$json.version) {
        Write-Host -f Red "Invalid manifest: $manifest ..."
        return
    }
    $version = $json.version

    if($push -eq $true) {
        Write-Host -f DarkCyan "Creating update $app ($version) ..."
        execute "hub add $manifest"
        execute "hub commit -m 'Update $app to version $version'"
    } else {
        pull_requests $json $app $upstream $manifest
    }
}

if($push -eq $true) {
    Write-Host -f DarkCyan "Pushing updates ..."
    execute "hub push origin master"
} else {
    Write-Host -f DarkCyan "Returning to master branch and removing unstaged files ..."
    execute "hub checkout -f master"
}

execute "hub reset"
