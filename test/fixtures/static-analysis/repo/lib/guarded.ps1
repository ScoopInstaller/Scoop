# !fixture_flag here contradicts fixture_flag at the call site, so the branch is never followed.
function fixture_guarded_helper {
    if (-not (get_config fixture_flag)) {
        fixture_never_helper
    }
}

# The first branch is reported; the else branch's inner call contradicts its inverted guard.
function fixture_else_helper {
    if (get_config fixture_flag) {
        fixture_never_helper
    } else {
        if (get_config fixture_flag) {
            fixture_never_helper
        }
    }
}
