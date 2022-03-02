. "$PSScriptRoot\..\lib\core.ps1"

Describe 'config' -Tag 'Scoop' {
    BeforeAll {
        $scoopConfig = $null
        $configFile = "$PSScriptRoot\tmp\config.json"
        if (Test-Path $configFile) {
            Remove-Item -Path $configFile -Force
        }
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
        $scoopConfig = set_config 'time' ([System.DateTime]::Parse("2019-03-18T15:22:09.3930000+00:00"))
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $scoopConfig.time | Should -BeOfType [System.String]
        } else {
            $scoopConfig.time | Should -BeOfType [System.DateTime]
        }

        # non-ASCII
        $scoopConfig = set_config 'unicode' '你好こんにちは'
        $scoopConfig.unicode | Should -Be '你好こんにちは'
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
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $scoopConfig.time | Should -BeOfType [System.String]
        } else {
            $scoopConfig.time | Should -BeOfType [System.DateTime]
        }
        $scoopConfig.unicode | Should -Be '你好こんにちは'
    }

    It 'get_config should return exactly the same values' {
        $scoopConfig = load_cfg $configFile
        (get_config 'one') | Should -BeExactly 1
        (get_config 'two') | Should -BeTrue
        (get_config 'three') | Should -BeFalse
        (get_config 'under_line') | Should -BeExactly 'four'
        (get_config 'five') | Should -Be 'not null'
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            (get_config 'time') | Should -BeOfType [System.String]
        } else {
            (get_config 'time') | Should -BeOfType [System.DateTime]
        }
        (get_config 'unicode') | Should -Be '你好こんにちは'
    }

    It "set_config should remove a value if being set to `$null" {
        $scoopConfig = load_cfg $configFile
        $scoopConfig = set_config 'five' $null
        $scoopConfig.five | Should -BeNullOrEmpty
    }
}
