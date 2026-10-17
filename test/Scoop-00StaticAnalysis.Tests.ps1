Describe 'Dot-sourced dependencies' -Tag 'Scoop' {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\supporting\Scoop.StaticAnalysis.psm1" -Force
        $issues = @(Get-DotSourceIssue -Root (Resolve-Path "$PSScriptRoot\..").Path)
    }

    It 'Every function an entry point calls is loaded before it runs' {
        $report = ($issues | ForEach-Object {
            '{0}: {1} -> {2}:{3} calls {4} (defined in {5})' -f
            $_.Entry, ($_.Chain -join ' -> '), (Split-Path $_.Path -Leaf), $_.Line, $_.Name, $_.DefinedIn
        }) -join "`n"

        $issues | Should-BeCollection -Count 0 -Because $report
    }
}
