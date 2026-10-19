function fixture_outer_runner {
    function fixture_inner_loader {
        fixture_amp_target
        . "$PSScriptRoot\link.ps1"
        & "$PSScriptRoot\unloaded.ps1"
    }
    fixture_inner_loader
}
fixture_outer_runner
