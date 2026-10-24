BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\versions.ps1"
}

Describe 'versions comparison' -Tag 'Scoop' {
    It 'loads the compiled comparer' {
        [bool]('Scoop.SemVerComparer' -as [Type]) | Should-BeTrue
    }

    Context 'semver compliant versions' {
        It 'handles major.minor.patch progressing' {
            [Scoop.SemVerComparer]::Compare('0.1.0', '0.1.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.1', '0.2.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.2.0', '1.0.0') | Should-Be 1
        }

        It 'handles pre-release versioning progression' {
            [Scoop.SemVerComparer]::Compare('0.4.0', '0.5.0-alpha.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5.0-alpha.1', '0.5.0-alpha.2') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5.0-alpha.2', '0.5.0-alpha.10') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5.0-alpha.10', '0.5.0-beta') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5.0-beta', '0.5.0-alpha.10') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('0.5.0-beta', '0.5.0-beta.0') | Should-Be 1
        }

        It 'handles the pre-release tags in an alphabetic order' {
            [Scoop.SemVerComparer]::Compare('0.5.0-rc.1', '0.5.0-z') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5.0-rc.1', '0.5.0-howdy') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('0.5.0-howdy', '0.5.0-rc.1') | Should-Be 1
        }
    }

    Context 'semver semi-compliant versions' {
        It 'handles Windows-styled major.minor.patch.build progression' {
            [Scoop.SemVerComparer]::Compare('0.0.0.0', '0.0.0.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.0.1', '0.0.0.2') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.0.2', '0.0.1.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.1.0', '0.0.1.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.1.1', '0.0.1.2') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.1.2', '0.0.2.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.0.2.0', '0.1.0.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.0.0', '0.1.0.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.0.1', '0.1.0.2') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.0.2', '0.1.1.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.1.0', '0.1.1.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.1.1', '0.1.1.2') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.1.1.2', '0.2.0.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.2.0.0', '1.0.0.0') | Should-Be 1
        }

        It 'handles partial semver version differences' {
            [Scoop.SemVerComparer]::Compare('1', '1.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1', '1.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.1.0.0', '1.1') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.4', '1.3.0') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.4', '1.3.255.255') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.4', '1.4.4') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.1.1_8', '1.1.1') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.1.1_8', '1.1.1_9') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.1.1_10', '1.1.1_9') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.1.1b', '1.1.1a') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('1.1.1a', '1.1.1b') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.1a2', '1.1a3') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.1.1a10', '1.1.1b1') | Should-Be 1
        }

        It 'returns a number when the versions only differ in a separated suffix' {
            [Scoop.SemVerComparer]::Compare('6', '6_') | Should-Be 0
            [Scoop.SemVerComparer]::Compare('1.4.6', '1.4.6_rev1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('25.0.0-36.0', '25.0.0-36.0.LTS') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('4.14', '4.14_BETA') | Should-Be -1
        }

        It 'handles dash-style versions' {
            [Scoop.SemVerComparer]::Compare('1.8.9', '1.8.5-1') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('7.0.4-9', '7.0.4-10') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('7.0.4-9', '7.0.4-8') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('2019-01-01', '2019-01-02') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('2019-01-02', '2019-01-01') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('2018-01-01', '2019-01-01') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('2019-01-01', '2018-01-01') | Should-Be -1
        }
        It 'handles post-release tagging ("+")' {
            [Scoop.SemVerComparer]::Compare('1', '1+hotfix.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.0.0', '1.0.0+hotfix.0') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.0.0+hotfix.0', '1.0.0+hotfix.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.0.0+hotfix.1', '1.0.1') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('1.0.0+1.1', '1.0.0+1') | Should-Be -1
        }
    }

    Context 'other misc versions' {
        It 'handles plain text string' {
            [Scoop.SemVerComparer]::Compare('latest', '20150405') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('0.5alpha', '0.5') | Should-Be 1
            [Scoop.SemVerComparer]::Compare('0.5', '0.5Beta') | Should-Be -1
            [Scoop.SemVerComparer]::Compare('0.4', '0.5Beta') | Should-Be 1
        }

        It 'handles empty string' {
            [Scoop.SemVerComparer]::Compare('7.0.4-9', '') | Should-Be -1
        }

        It 'handles equal versions' {
            $script:UpdateNightly = $null
            [Scoop.SemVerComparer]::Compare('12.0', '12.0') | Should-Be 0
            [Scoop.SemVerComparer]::Compare('7.0.4-9', '7.0.4-9') | Should-Be 0
            [Scoop.SemVerComparer]::Compare('nightly-20190801', 'nightly') | Should-Be 0
            [Scoop.SemVerComparer]::Compare('nightly-20190801', 'nightly-20200801') | Should-Be 0
        }

        It "handles nightly versions with 'update_nightly'" {
            $script:UpdateNightly = $null
            # a bare 'nightly' is the newest build, so it always wins against a dated one
            [Scoop.SemVerComparer]::Compare('nightly-20200801', 'nightly', $true) | Should-Be 1
            [Scoop.SemVerComparer]::Compare('nightly-20200730', 'nightly', $true) | Should-Be 1
            [Scoop.SemVerComparer]::Compare('nightly-20200730', 'nightly-20200801', $true) | Should-Be 1
            [Scoop.SemVerComparer]::Compare('nightly-20200802', 'nightly', $true) | Should-Be 1
            [Scoop.SemVerComparer]::Compare('nightly-20200802', 'nightly-20200801', $true) | Should-Be -1
            # without the flag, nightly builds compare equal
            [Scoop.SemVerComparer]::Compare('nightly-20200730', 'nightly-20200801') | Should-Be 0
            # two bare nightlies are the same build
            [Scoop.SemVerComparer]::Compare('nightly', 'nightly', $true) | Should-Be 0
        }

        It 'treats a mixed-case nightly prefix as nightly' {
            $script:UpdateNightly = $null
            [Scoop.SemVerComparer]::Compare('NIGHTLY', 'nightly') | Should-Be 0
            [Scoop.SemVerComparer]::Compare('Nightly', 'nightly-20200801', $true) | Should-Be -1
            [Scoop.SemVerComparer]::Compare('Nightly-20200801', 'nightly-20200802', $true) | Should-Be 1
        }
    }
}
