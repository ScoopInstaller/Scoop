function fixture_early { fixture_late_helper }
fixture_early

fixture_late_helper
. "$PSScriptRoot\..\lib\host.ps1"

fixture_never_helper

if (get_config fixture_flag) {
    fixture_guarded_helper
} else {
    fixture_guarded_helper
}

if (get_config fixture_flag) {
    fixture_else_helper
}

if ((get_config fixture_flag) -and ($app -ne 'scoop')) {
    fixture_never_helper
} else {
    fixture_never_helper
}

fixture_outer

fixture_order_helper
function fixture_order_helper { 'order' }

fixture_host_helper
fixture_link_helper
fixture_still_used
