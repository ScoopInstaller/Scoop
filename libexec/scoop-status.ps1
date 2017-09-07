# Usage: scoop status
# Summary: Show status and check for new app versions

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\git.ps1"

reset_aliases

# check if scoop needs updating
$currentdir = fullpath $(versiondir 'scoop' 'current')
$needs_update = $false

if(test-path "$currentdir\.git") {
    pushd $currentdir
    git_fetch -q origin
    $commits = $(git log "HEAD..origin/$(scoop config SCOOP_BRANCH)" --oneline)
    if($commits) { $needs_update = $true }
    popd
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

$true, $false | % { # local and global apps
    $global = $_
    $dir = appsdir $global
    if(!(test-path $dir)) { return }

    gci $dir | ? name -ne 'scoop' | % {
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
        }
        if($status.missing_deps) {
            $missing_deps += ,(@($app) + @($status.missing_deps))
        }
    }
}

if($outdated) {
    write-host -f DarkCyan 'Updates are available for:'
    $outdated.keys | % {
        $versions = $outdated.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($removed) {
    write-host -f DarkCyan 'These app manifests have been removed:'
    $removed.keys | % {
        "    $_"
    }
}

if($failed) {
    write-host -f DarkCyan 'These apps failed to install:'
    $failed.keys | % {
        "    $_"
    }
}

if($missing_deps) {
    write-host -f DarkCyan 'Missing runtime dependencies:'
    $missing_deps | % {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if(!$old -and !$removed -and !$failed -and !$missing_deps -and !$needs_update) {
    success "Everything is ok!"
}

exit 0
