<#
.SYNOPSIS
    Updates manifests and pushes them or creates pull-requests.
.DESCRIPTION
    Updates manifests and pushes them directly to the master branch or creates pull-requests for upstream.
.PARAMETER Upstream
    Upstream repository with target branch.
    Must be in format '<user>/<repo>:<branch>'
.PARAMETER Dir
    Directory where to search for manifests.
.PARAMETER Push
    Push updates directly to 'origin master'.
.PARAMETER Request
    Create pull-requests on 'upstream master' for each update.
.PARAMETER Help
    Print help to console.
.PARAMETER SpecialSnoflakes
    Array of manifests, which should be updated all the time. (-ForceUpdate paramter to checkver)
.EXAMPLE
    PS REPODIR > .\bin\auto-pr.ps1 'someUsername/repository:branch' -Request
.EXAMPLE
    PS REPODIR > .\bin\auto-pr.ps1 -Push
    Update all manifests inside 'bucket/' directory.
#>
param(
    [String] $Upstream = "lukesampson/scoop:master",
    [String] $Dir,
    [Switch] $Push,
    [Switch] $Request,
    [Switch] $Help,
    [string[]] $SpecialSnowflakes
)

if (!$Dir) { $Dir = "$psscriptroot\..\bucket" }
$Dir = resolve-path $Dir

. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\unix.ps1"

if ((!$Push -and !$Request) -or $Help) {
    Write-Host @"
Usage: auto-pr.ps1 [OPTION]

Mandatory options:
  -p,  -push                       push updates directly to 'origin master'
  -r,  -request                    create pull-requests on 'upstream master' for each update

Optional options:
  -u,  -upstream                   upstream repository with target branch
                                     only used if -r is set (default: lukesampson/scoop:master)
  -h,  -help
"@
    exit 0
}

if (is_unix) {
    if (!(which hub)) {
        Write-Host -f yellow "Please install hub ('brew install hub' or visit: https://hub.github.com/)"
        exit 1
    }
} else {
    if (!(scoop which hub)) {
        Write-Host -f yellow "Please install hub 'scoop install hub'"
        exit 1
    }
}

if (!($Upstream -match "^(.*)\/(.*):(.*)$")) {
    abort "Upstream must have this format: <user>/<repo>:<branch>"
}

function execute($cmd) {
    Write-Host -f Green $cmd
    $output = Invoke-Expression $cmd

    if ($LASTEXITCODE -gt 0) {
        abort "^^^ Error! See above ^^^ (last command: $cmd)"
    }
    return $output
}

function pull_requests($json, [String]$app, [String]$upstream, [String]$manifest) {
    $version = $json.version
    $homepage = $json.homepage
    $branch = "manifest/$app-$version"

    execute "hub checkout master"
    Write-Host -f Green "hub rev-parse --verify $branch"
    hub rev-parse --verify $branch

    if ($LASTEXITCODE -eq 0) {
        Write-Host -f Yellow "Skipping update $app ($version) ..."
        return
    }

    Write-Host -f DarkCyan "Creating update $app ($version) ..."
    execute "hub checkout -b $branch"
    execute "hub add $manifest"
    execute "hub commit -m '${app}: Update to version $version'"
    Write-Host -f DarkCyan "Pushing update $app ($version) ..."
    execute "hub push origin $branch"

    if ($LASTEXITCODE -gt 0) {
        error "Push failed! (hub push origin $branch)"
        execute "hub reset"
        return
    }
    Start-Sleep 1
    Write-Host -f DarkCyan "Pull-Request update $app ($version) ..."
    Write-Host -f green "hub pull-request -m '<msg>' -b '$upstream' -h '$branch'"

    $msg = @"
$app`: Update to version $version

Hello lovely humans,
a new version of [$app]($homepage) is available.

| State | Update :rocket: |
| :---: | :-------------: |
| New Version | $version  |
"@

    hub pull-request -m "$msg" -b '$upstream' -h '$branch'
    if ($LASTEXITCODE -gt 0) {
        execute "hub reset"
        abort "Pull Request failed! (hub pull-request -m '${app}: Update to version $version' -b '$upstream' -h '$branch')"
    }
}

Write-Host -f DarkCyan "Updating ..."
if ($Push) {
    execute("hub pull origin master")
    execute "hub checkout master"
} else {
    execute("hub pull upstream master")
    execute("hub push origin master")
}

. "$psscriptroot\checkver.ps1" * -update -dir $Dir
if ($SpecialSnowflakes) {
    write-host -f DarkCyan "Forcing update on our special snowflakes: $($SpecialSnowflakes -join ',')"
    $SpecialSnowflakes -split ',' | ForEach-Object {
        . "$psscriptroot\checkver.ps1" $_ -update -forceUpdate -dir $Dir
    }
}

hub diff --name-only | ForEach-Object {
    $manifest = $_
    if (!$manifest.EndsWith(".json")) {
        return
    }

    $app = ([System.IO.Path]::GetFileNameWithoutExtension($manifest))
    $json = parse_json $manifest
    if (!$json.version) {
        error "Invalid manifest: $manifest ..."
        return
    }
    $version = $json.version

    if ($Push) {
        Write-Host -f DarkCyan "Creating update $app ($version) ..."
        execute "hub add $manifest"

        # detect if file was staged, because it's not when only LF or CRLF have changed
        $status = Invoke-Expression "hub status --porcelain -uno"
        $status = $status | select-object -first 1
        if ($status -and $status.StartsWith('M  ') -and $status.EndsWith("$app.json")) {
            execute "hub commit -m '${app}: Update to version $version'"
        } else {
            Write-Host -f Yellow "Skipping $app because only LF/CRLF changes were detected ..."
        }
    } else {
        pull_requests $json $app $Upstream $manifest
    }
}

if ($Push) {
    Write-Host -f DarkCyan "Pushing updates ..."
    execute "hub push origin master"
} else {
    Write-Host -f DarkCyan "Returning to master branch and removing unstaged files ..."
    execute "hub checkout -f master"
}

execute "hub reset"
