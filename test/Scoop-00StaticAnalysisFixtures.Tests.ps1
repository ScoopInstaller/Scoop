Describe 'Static analysis fixtures' -Tag 'Scoop' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\supporting\Scoop.StaticAnalysis.psm1" -Force
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures\static-analysis\repo'
        $bucketRoot = Join-Path $PSScriptRoot 'fixtures\manifest'
        $issues = @(Get-DotSourceIssue -Root $fixtureRoot)
        $unreachable = @(Get-UnreachableFunction -Root $fixtureRoot)
        $deprecated = @(Get-DeprecatedFunction -Root $fixtureRoot)
        $usage = @(Get-DeprecatedManifestUsage -Root $fixtureRoot -Dir $bucketRoot)
    }

    Context 'Get-DotSourceIssue' {
        It 'Reports every call the entry point cannot see' {
            $report = ($issues | ForEach-Object {
                '{0}: {1} -> {2}:{3} calls {4}' -f $_.Entry, ($_.Chain -join ' -> '), (Split-Path $_.Path -Leaf), $_.Line, $_.Name
            }) -join "`n"

            $issues | Should-BeCollection -Count 6 -Because $report
        }

        It 'Reports <Name> in <Entry>' -TestCases @(
            @{ Entry = 'entry-late.ps1'; Name = 'fixture_late_helper'; Path = 'entry-late.ps1'; Line = 1 }
            @{ Entry = 'entry-never.ps1'; Name = 'fixture_never_helper'; Path = 'entry-never.ps1'; Line = 2 }
            @{ Entry = 'entry-nested.ps1'; Name = 'fixture_never_helper'; Path = 'nested.ps1'; Line = 3 }
            @{ Entry = 'dispatch.ps1'; Name = 'fixture_never_helper'; Path = 'dispatch.ps1'; Line = 2 }
            @{ Entry = 'entry-order.ps1'; Name = 'fixture_order_helper'; Path = 'entry-order.ps1'; Line = 1 }
        ) {
            $hits = @($issues | Where-Object { $_.Entry -eq $Entry -and $_.Name -eq $Name })
            $hits | Should-BeCollection -Count 1
            (Split-Path $hits[0].Path -Leaf) | Should-Be $Path
            $hits[0].Line | Should-Be $Line
        }

        It 'Reports nothing for the entry that loads before it calls' {
            @($issues | Where-Object { $_.Entry -eq 'entry-fine.ps1' }) | Should-BeCollection -Count 0
        }

        It 'Skips branches whose get_config guards contradict the call site' {
            @($issues | Where-Object { $_.Entry -eq 'entry-guarded.ps1' }) | Should-BeCollection -Count 0
        }

        It 'Inverts else-branch guards so only the reachable branch is followed' {
            # A broken else derivation would follow the else branch too and report two issues.
            @($issues | Where-Object { $_.Entry -eq 'entry-else.ps1' }) | Should-BeCollection -Count 1
        }
    }

    Context 'Get-UnreachableFunction' {
        It 'Reports only the functions nothing calls' {
            $report = ($unreachable | ForEach-Object { '{0} deprecated={1}' -f $_.Name, $_.Deprecated }) -join "`n"

            $unreachable | Should-BeCollection -Count 3 -Because $report
            @($unreachable | Where-Object { $_.Name -eq 'fixture_inner' }) | Should-BeCollection -Count 0
        }

        It 'Reports <Name> as Deprecated=<Deprecated> ReplacedBy=<ReplacedBy>' -TestCases @(
            @{ Name = 'fixture_orphan'; Deprecated = $false; ReplacedBy = '' }
            @{ Name = 'fixture_old_way'; Deprecated = $true; ReplacedBy = '' }
            @{ Name = 'fixture_replaced_way'; Deprecated = $true; ReplacedBy = 'fixture_new_way' }
        ) {
            $fn = @($unreachable | Where-Object { $_.Name -eq $Name })
            $fn | Should-BeCollection -Count 1
            $fn[0].Deprecated | Should-Be $Deprecated
            $fn[0].ReplacedBy | Should-Be $ReplacedBy
        }
    }

    Context 'Get-DeprecatedFunction' {
        It 'Lists <Name> with ReplacedBy <ReplacedBy>' -TestCases @(
            @{ Name = 'fixture_old_way'; ReplacedBy = '' }
            @{ Name = 'fixture_replaced_way'; ReplacedBy = 'fixture_new_way' }
            @{ Name = 'fixture_still_used'; ReplacedBy = 'fixture_modern_way' }
        ) {
            $fn = @($deprecated | Where-Object { $_.Name -eq $Name })
            $fn | Should-BeCollection -Count 1
            $fn[0].ReplacedBy | Should-Be $ReplacedBy
        }

        It 'Includes deprecated functions that are still reachable' {
            @($unreachable | Where-Object { $_.Name -eq 'fixture_still_used' }) | Should-BeCollection -Count 0
        }
    }

    Context 'Get-DeprecatedManifestUsage' {
        It 'Flags <Name> -> <ReplacedBy> in deprecated_app' -TestCases @(
            @{ Name = 'fixture_old_way'; ReplacedBy = '' }
            @{ Name = 'fixture_replaced_way'; ReplacedBy = 'fixture_new_way' }
            @{ Name = 'fixture_still_used'; ReplacedBy = 'fixture_modern_way' }
        ) {
            $app = @($usage | Where-Object { $_.Manifest -eq 'deprecated_app' })
            $app[0].Failed | Should-BeFalse
            $app[0].Found[$Name] | Should-Be $ReplacedBy
        }

        It 'Keeps exactly the three calls in deprecated_app' {
            $app = @($usage | Where-Object { $_.Manifest -eq 'deprecated_app' })
            @($app[0].Found.Keys) | Should-BeCollection -Count 3
            $app[0].File | Should-Be 'deprecated_app.json'
        }

        It 'Leaves prose, comments and non-script fields alone' {
            $clean = @($usage | Where-Object { $_.Manifest -eq 'clean_app' })
            $clean[0].Failed | Should-BeFalse
            @($clean[0].Found.Keys) | Should-BeCollection -Count 0
        }

        It 'Flags manifests that fail to parse' {
            $broken = @($usage | Where-Object { $_.Manifest -eq 'broken_wget' })
            $broken[0].Failed | Should-BeTrue
            $broken[0].File | Should-Be 'broken_wget.json'
        }
    }
}
