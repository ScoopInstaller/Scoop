Describe 'PSScriptAnalyzer' -Tag 'Linter' {
    BeforeDiscovery {
        $scriptDir = @('.', 'bin', 'lib', 'libexec', 'test')
    }

    BeforeAll {
        $lintSettings = "$PSScriptRoot\..\PSScriptAnalyzerSettings.psd1"
    }

    It 'PSScriptAnalyzerSettings.ps1 should exist' {
        $lintSettings | Should -Exist
    }

    Context 'Linting all *.psd1, *.psm1 and *.ps1 files' {
        BeforeEach {
            $analysis = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\$_" -Settings $lintSettings
        }
        It 'Should pass: <_>' -TestCases $scriptDir {
            $analysis | Should -HaveCount 0
            if ($analysis) {
                foreach ($result in $analysis) {
                    switch -wildCard ($result.ScriptName) {
                        '*.psm1' { $type = 'Module' }
                        '*.ps1' { $type = 'Script' }
                        '*.psd1' { $type = 'Manifest' }
                    }
                    Write-Warning "     [*] $($result.Severity): $($result.Message)"
                    Write-Warning "         $($result.RuleName) in $type`: $directory\$($result.ScriptName):$($result.Line)"
                }
            }
        }
    }
}
