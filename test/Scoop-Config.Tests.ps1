. "$PSScriptRoot\..\lib\core.ps1"

Describe 'config' -Tag 'Scoop' {
    BeforeAll {
        $configFile = "$env:TEMP\ScoopTestFixtures\config.json"
        if (Test-Path $configFile) {
            Remove-Item -Path $configFile -Force
        }
        $unicode = [Regex]::Unescape('\u4f60\u597d\u3053\u3093\u306b\u3061\u306f') # 你好こんにちは
    }

    BeforeEach {
        $scoopConfig = $null
    }

    It 'load_cfg should return null if config file does not exist' {
        load_cfg $configFile | Should -Be $null
    }

    It 'set_config should be able to save typed values correctly' {
        # number
        $scoopConfig = set_config 'one' 1
        $scoopConfig.one | Should -BeExactly 1

        # boolean
        $scoopConfig = set_config 'two' $true
        $scoopConfig.two | Should -BeTrue
        $scoopConfig = set_config 'three' $false
        $scoopConfig.three | Should -BeFalse

        # underline key
        $scoopConfig = set_config 'under_line' 'four'
        $scoopConfig.under_line | Should -BeExactly 'four'

        # string
        $scoopConfig = set_config 'five' 'not null'

        # datetime
        $scoopConfig = set_config 'time' ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        $scoopConfig.time | Should -BeOfType [System.DateTime]

        # non-ASCII
        $scoopConfig = set_config 'unicode' $unicode
        $scoopConfig.unicode | Should -Be $unicode
    }

    It 'load_cfg should return PSObject if config file exist' {
        $scoopConfig = load_cfg $configFile
        $scoopConfig | Should -Not -BeNullOrEmpty
        $scoopConfig | Should -BeOfType [System.Management.Automation.PSObject]
        $scoopConfig.one | Should -BeExactly 1
        $scoopConfig.two | Should -BeTrue
        $scoopConfig.three | Should -BeFalse
        $scoopConfig.under_line | Should -BeExactly 'four'
        $scoopConfig.five | Should -Be 'not null'
        $scoopConfig.time | Should -BeOfType [System.DateTime]
        $scoopConfig.time | Should -Be ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        $scoopConfig.unicode | Should -Be $unicode
    }

    It 'get_config should return exactly the same values' {
        $scoopConfig = load_cfg $configFile
        (get_config 'one') | Should -BeExactly 1
        (get_config 'two') | Should -BeTrue
        (get_config 'three') | Should -BeFalse
        (get_config 'under_line') | Should -BeExactly 'four'
        (get_config 'five') | Should -Be 'not null'
        (get_config 'time') | Should -BeOfType [System.DateTime]
        (get_config 'time') | Should -Be ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        (get_config 'unicode') | Should -Be $unicode
    }

    It 'set_config should remove a value if being set to $null' {
        $scoopConfig = load_cfg $configFile
        $scoopConfig = set_config 'five' $null
        $scoopConfig.five | Should -BeNullOrEmpty
    }
}
