. "$PSScriptRoot\link.ps1"

fixture_top_helper

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

function fixture_still_used {
    Show-DeprecatedWarning $MyInvocation 'fixture_modern_way'
}
