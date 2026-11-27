Describe 'Dot-sourced dependencies' -Tag 'Scoop' {
    BeforeAll {
        Import-Module (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'supporting') 'Scoop.StaticAnalysis.psm1') -Force
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $issues = @(Get-DotSourceIssue -Root $root)
        $entries = @(Get-ChildItem (Join-Path $root 'bin'), (Join-Path $root 'libexec') -Filter *.ps1)
    }

    It 'Scans the bin and libexec entry points' {
        # Guards the gate below against an empty run that would pass vacuously.
        $entries.Count | Should-BeGreaterThan 0
    }

    It 'Every function an entry point calls is loaded before it runs' {
        $report = ($issues | ForEach-Object {
            '{0}: {1} -> {2}:{3} calls {4} (defined in {5})' -f
            $_.Entry, ($_.Chain -join ' -> '), (Split-Path $_.Path -Leaf), $_.Line, $_.Name, $_.DefinedIn
        }) -join "`n"

        $issues | Should-BeCollection -Count 0 -Because $report
    }
}
