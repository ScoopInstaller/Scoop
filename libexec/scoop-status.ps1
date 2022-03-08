# Usage: scoop status
# Summary: Show status and check for new app versions

. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\depends.ps1"

reset_aliases

# check if scoop needs updating
$currentdir = fullpath $(versiondir 'scoop' 'current')
$needs_update = $false

if(Test-Path "$currentdir\.git") {
    git_cmd -C "`"$currentdir`"" fetch -q origin
    $commits = $(git -C $currentdir log "HEAD..origin/$(scoop config SCOOP_BRANCH)" --oneline)
    if($commits) { $needs_update = $true }
}
else {
    $needs_update = $true
}

if($needs_update) {
    warn "Scoop is out of date. Run 'scoop update' to get the latest changes."
}
else { success "Scoop is up to date."}

$failed = @()
$outdated = @()
$removed = @()
$missing_deps = @()
$onhold = @()

$true, $false | ForEach-Object { # local and global apps
    $global = $_
    $dir = appsdir $global
    if(!(Test-Path $dir)) { return }

    Get-ChildItem $dir | Where-Object name -ne 'scoop' | ForEach-Object {
        $app = $_.name
        $status = app_status $app $global
        if($status.failed) {
            $failed += @{ $app = $status.version }
        }
        if($status.removed) {
            $removed += @{ $app = $status.version }
        }
        if($status.outdated) {
            $outdated += @{ $app = @($status.version, $status.latest_version) }
            if($status.hold) {
                $onhold += @{ $app = @($status.version, $status.latest_version) }
            }
        }
        if($status.missing_deps) {
            $missing_deps += ,(@($app) + @($status.missing_deps))
        }
    }
}

if($outdated) {
    Write-Host -f DarkCyan 'Updates are available for:'
    $outdated.keys | ForEach-Object {
        $versions = $outdated.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($onhold) {
    Write-Host -f DarkCyan 'These apps are outdated and on hold:'
    $onhold.keys | ForEach-Object {
        $versions = $onhold.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($removed) {
    Write-Host -f DarkCyan 'These app manifests have been removed:'
    $removed.keys | ForEach-Object {
        "    $_"
    }
}

if($failed) {
    Write-Host -f DarkCyan 'These apps failed to install:'
    $failed.keys | ForEach-Object {
        "    $_"
    }
}

if($missing_deps) {
    Write-Host -f DarkCyan 'Missing runtime dependencies:'
    $missing_deps | ForEach-Object {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if(!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update) {
    success "Everything is ok!"
}

exit 0
