& "$PSScriptRoot\..\libexec\dispatch.ps1"
& "$PSScriptRoot\..\lib\runner.ps1"

function fixture_nesting_caller {
    function fixture_nested_runner { & "$PSScriptRoot\..\lib\unloaded.ps1" }
    fixture_nested_runner
}
fixture_nesting_caller

& "$PSScriptRoot\..\lib\unloaded.ps1"
function fixture_future_helper { 'future' }
fixture_future_helper

function fixture_partial_negation {
    if (-not (get_config fixture_flag) -and $fixture_other) {
        fixture_deep_helper
    }
}
if (get_config fixture_flag) {
    fixture_partial_negation
}

function fixture_early { fixture_late_helper }
fixture_early

fixture_late_helper
. "$PSScriptRoot\..\lib\host.ps1"
fixture_deep_helper

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

if (-not (get_config fixture_flag)) {
    fixture_guarded_visitor
} else {
    fixture_guarded_visitor
}

function fixture_compound_caller {
    if ((get_config fixture_flag) -and ($app -ne 'scoop')) {
        fixture_quiet_helper
    } else {
        fixture_else_only_helper
    }
}
if (get_config fixture_flag) {
    fixture_compound_caller
}

function fixture_elseif_caller {
    if (get_config fixture_flag) {
        fixture_quiet_helper
    } elseif (get_config other_flag) {
        fixture_else_only_helper
    }
}
if (-not (get_config fixture_flag)) {
    fixture_elseif_caller
}

function fixture_or_caller {
    if ((get_config fixture_flag) -or (get_config other_flag)) {
        fixture_or_only_helper
    }
}
if (-not (get_config fixture_flag)) {
    fixture_or_caller
}

function fixture_elseif_not_caller {
    if (-not (get_config fixture_flag)) {
        fixture_quiet_helper
    } elseif (get_config other_flag) {
        fixture_else_only_helper
    }
}
if (-not (get_config fixture_flag)) {
    fixture_elseif_not_caller
}

& "$PSScriptRoot\..\lib\unloaded.ps1"

fixture_outer

fixture_order_helper
function fixture_order_helper { 'order' }

fixture_host_helper
fixture_link_helper
fixture_still_used
