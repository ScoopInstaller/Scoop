# Usage: scoop status
# Summary: Show status information

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\versions.ps1"

$failed = @()
$old = @()
$removed = @()

gci "$scoopdir\apps" | ? name -ne 'scoop' | % {
    $app = $_.name
    $version = @(versions $app)[-1]
    if($version) {
        $install_info = install_info $app $version
    }
    
    if(!$install_info) {
        $failed += @{ $app = $version }; return 
    }

    $manifest = manifest $app $install_info.url
    if(!$manifest) { $removed += @{ $app = $version }; return }

    if((compare_versions $manifest.version $version) -gt 0) {
        $old += @{ $app = @($version, $manifest.version) }
    }
}

if($old) {
    "Updates are available for:"
    $old.keys | % { 
        "    $_"
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

if(!$old -and !$removed -and !$failed) {
    "Everything is ok!"
}

exit 0