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
    "Scoop is out of date. Run 'scoop update' to get the latest changes."
}
else { "Scoop is up to date."}

$failed = @()
$old = @()
$removed = @()
$missing_deps = @()

$true, $false | % { # local and global apps
    $global = $_
    $dir = appsdir $global
    if(!(test-path $dir)) { return }

    gci $dir | ? name -ne 'scoop' | % {
        $app = $_.name
        $version = current_version $app $global
        if($version) {
            $install_info = install_info $app $version $global
        }

        if(!$install_info) {
            $failed += @{ $app = $version }; return
        }

        $manifest = manifest $app $install_info.bucket $install_info.url
        if(!$manifest) { $removed += @{ $app = $version }; return }

        if((compare_versions $manifest.version $version) -gt 0) {
            $old += @{ $app = @($version, $manifest.version) }
        }

        $deps = @(runtime_deps $manifest) | ? { !(installed $_) }
        if($deps) {
            $missing_deps += ,(@($app) + @($deps))
        }
    }
}



if($old) {
    "Updates are available for:"
    $old.keys | % {
        $versions = $old.$_
        "    $_`: $($versions[0]) -> $($versions[1])"
    }
}

if($removed) {
    "These app manifests have been removed:"
    $removed.keys | % {
        "    $_"
    }
}

if($failed) {
    "These apps failed to install:"
    $failed.keys | % {
        "    $_"
    }
}

if($missing_deps) {
    "Missing runtime dependencies:"
    $missing_deps | % {
        $app, $deps = $_
        "    '$app' requires '$([string]::join("', '", $deps))'"
    }
}

if(!$old -and !$removed -and !$failed -and !$missing_deps) {
    success "Everything is ok!"
}

exit 0
