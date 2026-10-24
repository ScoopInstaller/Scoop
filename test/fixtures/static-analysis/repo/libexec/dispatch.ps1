function fixture_scope_caller {
    function fixture_top_helper { 'shadow' }
    fixture_inner_owner
}
fixture_scope_caller
fixture_never_helper
