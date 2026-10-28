BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
}

Describe 'config' -Tag 'Scoop' {
    BeforeAll {
        $configFile = [IO.Path]::GetTempFileName()
        # pointing shimdir at a scratch tree is what keeps it off the real shims folder
        $scoopdir = Join-Path ([IO.Path]::GetTempPath()) 'ScoopConfigTest\root'
        $globaldir = Join-Path ([IO.Path]::GetTempPath()) 'ScoopConfigTest\global'
        New-Item -ItemType Directory -Force -Path "$scoopdir\shims", "$globaldir\shims" | Out-Null
        $unicode = [Regex]::Unescape('\u4f60\u597d\u3053\u3093\u306b\u3061\u306f') # 你好こんにちは
    }

    AfterAll {
        Remove-Item -Path $configFile -Force
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Split-Path $scoopdir)
    }

    It 'load_cfg should return null if config file does not exist' {
        load_cfg $configFile | Should-Be $null
    }

    Describe 'Complete-ConfigChange' {
        Context 'shim_auto_refresh' {
            BeforeEach {
                'clobbered' | Out-File "$scoopdir\shims\refresh-test.exe" -NoNewline
                'clobbered' | Out-File "$scoopdir\shims\refresh-test.shim" -NoNewline
                Mock get_config { $false } -ParameterFilter { $Name -eq 'NO_JUNCTION' }
                Mock info {}
            }

            AfterEach {
                Remove-Item -Force -ErrorAction SilentlyContinue "$scoopdir\shims\refresh-test.exe"
                Remove-Item -Force -ErrorAction SilentlyContinue "$scoopdir\shims\refresh-test.shim"
            }

            It 'leaves the copies alone when shim_auto_refresh is off' {
                Mock get_config { $false } -ParameterFilter { $Name -eq 'SHIM_AUTO_REFRESH' }

                Complete-ConfigChange -Name shim -Value 'scoop-shim-cs'

                [IO.File]::ReadAllText("$scoopdir\shims\refresh-test.exe") | Should-Be 'clobbered'
                Should-Invoke -CommandName info -Times 1 -ParameterFilter { $msg -like "*scoop shim update*" }
            }

            It 'refreshes with the value being set, not the one still on disk' {
                Mock get_config { $null } -ParameterFilter { $Name -eq 'SHIM' }
                Mock get_config { $true } -ParameterFilter { $Name -eq 'SHIM_AUTO_REFRESH' }

                Complete-ConfigChange -Name shim -Value $null 6>$null

                (Get-FileHash -LiteralPath "$scoopdir\shims\refresh-test.exe").Hash |
                    Should-Be (Get-FileHash -LiteralPath (Get-ShimTemplate)).Hash
            }
        }

        Context 'proxy' {
            It 'strips an http or https scheme' {
                (set_config 'proxy' 'http://10.0.0.1:8080').proxy | Should-Be '10.0.0.1:8080'
                (set_config 'proxy' 'https://user:pass@10.0.0.1:8080').proxy | Should-Be 'user:pass@10.0.0.1:8080'
            }

            It 'stores credentials that look like a scheme' {
                (set_config 'proxy' 'socks:pass@10.0.0.1:8080').proxy | Should-Be 'socks:pass@10.0.0.1:8080'
            }

            It 'rejects an unsupported scheme and keeps the stored value' {
                Mock abort { throw $msg }
                set_config 'proxy' '10.0.0.1:8080' | Out-Null

                { set_config 'proxy' 'ftp://10.0.0.1:8080' } | Should-Throw '*ftp://*'

                (get_config 'proxy') | Should-Be '10.0.0.1:8080'
            }

            It 'removes the value' {
                set_config 'proxy' $null | Out-Null

                (get_config 'proxy') | Should-Be $null
            }
        }
    }

    It 'set_config should be able to save typed values correctly' {
        # number
        $scoopConfig = set_config 'one' 1
        $scoopConfig.one | Should-Be 1

        # boolean
        $scoopConfig = set_config 'two' $true
        $scoopConfig.two | Should-BeTrue
        $scoopConfig = set_config 'three' $false
        $scoopConfig.three | Should-BeFalse

        # underline key
        $scoopConfig = set_config 'under_line' 'four'
        $scoopConfig.under_line | Should-BeString 'four' -CaseSensitive

        # string
        $scoopConfig = set_config 'five' 'not null'

        # datetime
        $scoopConfig = set_config 'time' ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        $scoopConfig.time | Should-HaveType ([System.DateTime])

        # non-ASCII
        $scoopConfig = set_config 'unicode' $unicode
        $scoopConfig.unicode | Should-Be $unicode
    }

    It 'load_cfg should return PSObject if config file exist' {
        $scoopConfig = load_cfg $configFile
        $scoopConfig | Should-NotBeNull
        $scoopConfig | Should-HaveType ([System.Management.Automation.PSObject])
        $scoopConfig.one | Should-Be 1
        $scoopConfig.two | Should-BeTrue
        $scoopConfig.three | Should-BeFalse
        $scoopConfig.under_line | Should-BeString 'four' -CaseSensitive
        $scoopConfig.five | Should-Be 'not null'
        $scoopConfig.time | Should-HaveType ([System.DateTime])
        $scoopConfig.time | Should-Be ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        $scoopConfig.unicode | Should-Be $unicode
    }

    It 'get_config should return exactly the same values' {
        $scoopConfig = load_cfg $configFile
        (get_config 'one') | Should-Be 1
        (get_config 'two') | Should-BeTrue
        (get_config 'three') | Should-BeFalse
        (get_config 'under_line') | Should-BeString 'four' -CaseSensitive
        (get_config 'five') | Should-Be 'not null'
        (get_config 'time') | Should-HaveType ([System.DateTime])
        (get_config 'time') | Should-Be ([System.DateTime]::Parse('2019-03-18T15:22:09.3930000+00:00', $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal))
        (get_config 'unicode') | Should-Be $unicode
    }

    It 'set_config should remove a value if being set to $null' {
        $scoopConfig = load_cfg $configFile
        $scoopConfig = set_config 'five' $null
        $scoopConfig.five | Should-BeNull
    }
}
