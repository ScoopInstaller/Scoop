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

            $issues | Should-BeCollection -Count 9 -Because $report
        }

        It 'Reports <Name> once per unreachable call' -TestCases @(
            @{ Name = 'fixture_late_helper'; Count = 1 }
            @{ Name = 'fixture_never_helper'; Count = 7 }
            @{ Name = 'fixture_order_helper'; Count = 1 }
        ) {
            @($issues | Where-Object { $_.Name -eq $Name }) | Should-BeCollection -Count $Count
        }

        It 'Does not report calls the entry point can see' {
            # The guarded branch contradicts its call site, the chained dot-source loads
            # with the library that pulls it in, and the nested body sees its owner.
            @($issues | Where-Object { $_.Name -eq 'fixture_guarded_helper' }) | Should-BeCollection -Count 0
            @($issues | Where-Object { $_.Name -eq 'fixture_link_helper' }) | Should-BeCollection -Count 0
            @($issues | Where-Object { $_.Name -eq 'fixture_host_helper' }) | Should-BeCollection -Count 0
            @($issues | Where-Object { $_.Name -eq 'fixture_inner_helper' }) | Should-BeCollection -Count 0
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
        ) {
            $fn = @($deprecated | Where-Object { $_.Name -eq $Name })
            $fn | Should-BeCollection -Count 1
            $fn[0].ReplacedBy | Should-Be $ReplacedBy
        }
    }

    Context 'Get-DeprecatedManifestUsage' {
        It 'Reports the deprecated calls in the manifest' {
            $app = @($usage | Where-Object { $_.Manifest -eq 'deprecated_app' })
            $app | Should-BeCollection -Count 1
            $app[0].Failed | Should-BeFalse
            @($app[0].Found.Keys) | Should-BeCollection -Count 3
            $app[0].Found['fixture_old_way'] | Should-Be ''
            $app[0].Found['fixture_replaced_way'] | Should-Be 'fixture_new_way'
            $app[0].Found['fixture_still_used'] | Should-Be 'fixture_modern_way'
        }

        It 'Ignores names that are not calls' {
            $clean = @($usage | Where-Object { $_.Manifest -eq 'clean_app' })
            $clean | Should-BeCollection -Count 1
            $clean[0].Failed | Should-BeFalse
            @($clean[0].Found.Keys) | Should-BeCollection -Count 0
        }
    }
}
