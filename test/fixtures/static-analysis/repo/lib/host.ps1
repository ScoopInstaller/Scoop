. "$PSScriptRoot\link.ps1"

fixture_top_helper
& "$PSScriptRoot\unloaded.ps1"

function fixture_host_helper { 'host' }

function fixture_late_helper { 'late' }

function fixture_guarded_helper {
    if (-not (get_config fixture_flag)) {
        fixture_never_helper
    }
}

function fixture_else_helper {
    if (get_config fixture_flag) {
        fixture_never_helper
    } else {
        if (get_config fixture_flag) {
            fixture_never_helper
        }
    }
}

function fixture_outer {
    function fixture_inner_helper { fixture_never_helper }
    fixture_inner_helper
}

function fixture_dynamic_helper { 'helper' }

function fixture_dynamic_target { fixture_dynamic_helper }

$fixture_dynamic = 'fixture_dynamic_target'

function fixture_inner_owner { function fixture_inner_name { 'inner' } }
fixture_inner_name

function fixture_guarded_visitor {
    if (get_config fixture_flag) {
        fixture_only_when_true
    } else {
        fixture_only_when_false
    }
}

function fixture_quiet_helper { 'quiet' }

function fixture_install_way {
    Show-DeprecatedWarning $MyInvocation 'fixture_modern_way'
}

function fixture_still_used {
    fixture_install_way
    Show-DeprecatedWarning $MyInvocation 'fixture_modern_way'
}
