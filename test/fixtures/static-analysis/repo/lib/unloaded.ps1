function fixture_never_helper { 'never' }

function fixture_top_helper { 'top' }

function fixture_only_when_true { 'true' }

function fixture_only_when_false { 'false' }

function fixture_else_only_helper { 'else' }

function fixture_or_only_helper { 'or' }

function fixture_orphan { 'orphan' }

function fixture_old_way {
    fixture_warn '"fixture_old_way" is deprecated'
}

function fixture_replaced_way {
    Show-DeprecatedWarning $MyInvocation 'fixture_new_way'
}
