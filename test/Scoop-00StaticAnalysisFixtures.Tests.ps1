Describe 'Static analysis fixtures' -Tag 'Scoop' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\supporting\Scoop.StaticAnalysis.psm1" -Force
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures\static-analysis\repo'
        $issues = @(Get-DotSourceIssue -Root $fixtureRoot)
    }

    It 'Reports every call the entry point cannot see' {
        $report = ($issues | ForEach-Object {
            '{0}: {1} -> {2}:{3} calls {4}' -f $_.Entry, ($_.Chain -join ' -> '), (Split-Path $_.Path -Leaf), $_.Line, $_.Name
        }) -join "`n"

        $issues | Should-BeCollection -Count 5 -Because $report
    }

    It 'Reports a call that runs before its dot-source' {
        @($issues | Where-Object { $_.Entry -eq 'entry-late.ps1' }) | Should-BeCollection -Count 1
        $late = @($issues | Where-Object { $_.Entry -eq 'entry-late.ps1' })
        $late[0].Name | Should-Be 'fixture_late_helper'
        (Split-Path $late[0].Path -Leaf) | Should-Be 'entry-late.ps1'
        $late[0].Line | Should-Be 1
    }

    It 'Reports a call to a file nothing loads' {
        $never = @($issues | Where-Object { $_.Entry -eq 'entry-never.ps1' })
        $never | Should-BeCollection -Count 1
        $never[0].Name | Should-Be 'fixture_never_helper'
    }

    It 'Reports a call an inherited host session still cannot see' {
        $dispatch = @($issues | Where-Object { $_.Entry -eq 'dispatch.ps1' })
        $dispatch | Should-BeCollection -Count 1
        $dispatch[0].Name | Should-Be 'fixture_never_helper'
    }

    It 'Checks calls inside nested function bodies with the owner''s visibility' {
        $nested = @($issues | Where-Object { $_.Entry -eq 'entry-nested.ps1' })
        $nested | Should-BeCollection -Count 1
        $nested[0].Name | Should-Be 'fixture_never_helper'
        (Split-Path $nested[0].Path -Leaf) | Should-Be 'nested.ps1'
    }

    It 'Skips branches whose get_config guards contradict the call site' {
        @($issues | Where-Object { $_.Entry -eq 'entry-guarded.ps1' }) | Should-BeCollection -Count 0
    }

    It 'Inverts else-branch guards so only the reachable branch is followed' {
        # A broken else derivation would follow the else branch too and report two issues.
        @($issues | Where-Object { $_.Entry -eq 'entry-else.ps1' }) | Should-BeCollection -Count 1
    }
}
