function fixture_dynamic_outer {
    function fixture_dynamic_inner { fixture_amp_target }
    $fixture_handler = 'fixture_dynamic_inner'
    & $fixture_handler
}
fixture_dynamic_outer

function fixture_dynamic_loaded {
    . "$PSScriptRoot\link.ps1"
    function fixture_dynamic_seen { fixture_amp_target }
    $fixture_picker = 'fixture_dynamic_seen'
    & $fixture_picker
}
fixture_dynamic_loaded

function fixture_outer_runner {
    function fixture_inner_loader {
        fixture_amp_target
        . "$PSScriptRoot\link.ps1"
        & "$PSScriptRoot\unloaded.ps1"
    }
    fixture_inner_loader
}
fixture_outer_runner
