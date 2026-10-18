function fixture_old_way {
    fixture_warn '"fixture_old_way" is deprecated'
}

function fixture_replaced_way {
    Show-DeprecatedWarning $MyInvocation 'fixture_new_way'
}

# Deprecated but still called: listed by Get-DeprecatedFunction, not by Get-UnreachableFunction.
function fixture_still_used {
    Show-DeprecatedWarning $MyInvocation 'fixture_modern_way'
}
