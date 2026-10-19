Describe 'Static analysis fixtures' -Tag 'Scoop' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\supporting\Scoop.StaticAnalysis.psm1" -Force
        $fixtureRoot = Join-Path $PSScriptRoot 'fixtures\static-analysis\repo'
        $issues = @(Get-DotSourceIssue -Root $fixtureRoot)
        $unreachable = @(Get-UnreachableFunction -Root $fixtureRoot)
        $deprecated = @(Get-DeprecatedFunction -Root $fixtureRoot)
        $usage = @(Get-DeprecatedManifestUsage -Root $fixtureRoot -Dir (Join-Path $PSScriptRoot 'fixtures\manifest'))
    }

    Context 'Get-DotSourceIssue' {
        It 'Reports every call the entry point cannot see' {
            $report = ($issues | ForEach-Object {
                '{0}: {1} -> {2}:{3} calls {4}' -f $_.Entry, ($_.Chain -join ' -> '), (Split-Path $_.Path -Leaf), $_.Line, $_.Name
            }) -join "`n"

            $issues | Should-BeCollection -Count 27 -Because $report
        }

        It 'Reports <Name> once per unreachable call' -TestCases @(
            @{ Name = 'fixture_late_helper'; Count = 2 }
            @{ Name = 'fixture_top_helper'; Count = 1 }
            @{ Name = 'fixture_inner_name'; Count = 2 }
            @{ Name = 'fixture_only_when_true'; Count = 1 }
            @{ Name = 'fixture_only_when_false'; Count = 1 }
            @{ Name = 'fixture_else_only_helper'; Count = 3 }
            @{ Name = 'fixture_or_only_helper'; Count = 1 }
            @{ Name = 'fixture_amp_target'; Count = 3 }
            @{ Name = 'fixture_future_helper'; Count = 5 }
            @{ Name = 'fixture_never_helper'; Count = 7 }
            @{ Name = 'fixture_order_helper'; Count = 1 }
        ) {
            @($issues | Where-Object { $_.Name -eq $Name }) | Should-BeCollection -Count $Count
        }

        It 'Does not report <Name>' -TestCases @(
            @{ Name = 'fixture_guarded_helper' }
            @{ Name = 'fixture_link_helper' }
            @{ Name = 'fixture_host_helper' }
            @{ Name = 'fixture_inner_helper' }
            @{ Name = 'fixture_self_helper' }
        ) {
            @($issues | Where-Object { $_.Name -eq $Name }) | Should-BeCollection -Count 0
        }
    }

    Context 'Get-UnreachableFunction' {
        It 'Reports only the functions nothing calls' {
            $report = ($unreachable | ForEach-Object { '{0} deprecated={1}' -f $_.Name, $_.Deprecated }) -join "`n"

            $unreachable | Should-BeCollection -Count 3 -Because $report
            @($unreachable | Where-Object { $_.Name -eq 'fixture_inner' }) | Should-BeCollection -Count 0
            @($unreachable | Where-Object { $_.Name -eq 'fixture_dynamic_helper' }) | Should-BeCollection -Count 0
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
            @{ Name = 'fixture_install_way'; ReplacedBy = 'fixture_modern_way' }
        ) {
            $fn = @($deprecated | Where-Object { $_.Name -eq $Name })
            $fn | Should-BeCollection -Count 1
            $fn[0].ReplacedBy | Should-Be $ReplacedBy
        }

        It 'Skips functions that only the test suite defines' {
            @($deprecated | Where-Object { $_.Name -eq 'fixture_test_deprecated' }) | Should-BeCollection -Count 0
        }
    }

    Context 'Get-DeprecatedManifestUsage' {
        It 'Reports the deprecated calls in the manifest' {
            $app = @($usage | Where-Object { $_.Manifest -eq 'deprecated_app' })
            $app | Should-BeCollection -Count 1
            $app[0].Failed | Should-BeFalse
            @($app[0].Found.Keys) | Should-BeCollection -Count 4
            $app[0].Found['fixture_old_way'] | Should-Be ''
            $app[0].Found['fixture_replaced_way'] | Should-Be 'fixture_new_way'
            $app[0].Found['fixture_still_used'] | Should-Be 'fixture_modern_way'
            $app[0].Found['fixture_install_way'] | Should-Be 'fixture_modern_way'
        }

        It 'Ignores names that are not calls' {
            $clean = @($usage | Where-Object { $_.Manifest -eq 'clean_app' })
            $clean | Should-BeCollection -Count 1
            $clean[0].Failed | Should-BeFalse
            @($clean[0].Found.Keys) | Should-BeCollection -Count 0
        }

        It 'Flags a manifest it cannot parse' {
            $broken = @($usage | Where-Object { $_.Manifest -eq 'broken_app' })
            $broken | Should-BeCollection -Count 1
            $broken[0].Failed | Should-BeTrue
            @($broken[0].Found.Keys) | Should-BeCollection -Count 0
        }
    }
}
