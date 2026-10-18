function fixture_never_helper { 'never' }

function fixture_top_helper { 'top' }

function fixture_orphan { 'orphan' }

function fixture_old_way {
    fixture_warn '"fixture_old_way" is deprecated'
}

function fixture_replaced_way {
    Show-DeprecatedWarning $MyInvocation 'fixture_new_way'
}
