$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName

Describe 'PSScriptAnalyzer' -Tag 'Linter' {
    $scoop_modules = Get-ChildItem $repo_dir -Recurse -Include *.psd1, *.psm1, *.ps1
    $scoop_modules = $scoop_modules | Where-Object { $_.DirectoryName -notlike '*\supporting*' -and $_.DirectoryName -notlike '*\test*' }
    $scoop_modules = $scoop_modules | Select-Object -ExpandProperty Directory -Unique

    Context 'Checking ScriptAnalyzer' {
        It 'Invoke-ScriptAnalyzer Cmdlet should exist' {
            { Get-Command Invoke-ScriptAnalyzer -ErrorAction Stop } | Should -Not -Throw
        }
        It 'PSScriptAnalyzerSettings.ps1 should exist' {
            Test-Path "$repo_dir\PSScriptAnalyzerSettings.psd1" | Should -BeTrue
        }
        It 'There should be files to test' {
            $scoop_modules.Count | Should -Not -Be 0
        }
    }

    $linting_settings = Get-Item -Path "$repo_dir\PSScriptAnalyzerSettings.psd1"

    Context 'Linting all *.psd1, *.psm1 and *.ps1 files' {
        foreach ($directory in $scoop_modules) {
            $analysis = Invoke-ScriptAnalyzer -Path $directory.FullName -Settings $linting_settings.FullName
            It "Should pass: $directory" {
                $analysis.Count | Should -Be 0
            }
            if ($analysis) {
                foreach ($result in $analysis) {
                    switch -wildCard ($result.ScriptName) {
                        '*.psm1' { $type = 'Module' }
                        '*.ps1' { $type = 'Script' }
                        '*.psd1' { $type = 'Manifest' }
                    }
                    Write-Host -f Yellow "      [*] $($result.Severity): $($result.Message)"
                    Write-Host -f Yellow "          $($result.RuleName) in $type`: $directory\$($result.ScriptName):$($result.Line)"
                }
            }
        }
    }
}
