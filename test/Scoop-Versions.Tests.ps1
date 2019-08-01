. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\versions.ps1"

describe "versions" -Tag 'Scoop' {
    it 'compares versions with integer-string mismatch' {
        Compare-Version '1.8.9' '1.8.5-1' | Should -Be -1
    }

    it 'handles plain string version comparison to int version' {
        Compare-Version 'latest' '20150405' | Should -Be -1
        Compare-Version '0.5alpha' '0.5' | Should -Be 1
        Compare-Version '0.5' '0.5Beta' | Should -Be -1
    }

    it 'handles dashed version components' {
        Compare-Version '7.0.4-9' '7.0.4-10' | Should -Be 1
        Compare-Version '7.0.4' '7.0.4-9' | Should -Be 1
        Compare-Version '7.0.4-beta9' '7.0.4' | Should -Be 1
        Compare-Version '7.0.4-9' '7.0.4-8' | Should -Be -1
        Compare-Version '7.0.4' '7.0.4-beta9' | Should -Be -1
    }

    it 'handle example comparisons' {
        Compare-Version '1' '1.1' | Should -Be 1
        Compare-Version '1.0' '1.1' | Should -Be 1
        Compare-Version '1.9.8' '1.10.0' | Should -Be 1
        Compare-Version '1.1' '1.0' | Should -Be -1
        Compare-Version '1.1' '1' | Should -Be -1
        Compare-Version '1.10.0' '1.9.8' | Should -Be -1
        Compare-Version '1.1.1_8' '1.1.1' | Should -Be -1
        Compare-Version '1.1.1b' '1.1.1a' | Should -Be -1
        Compare-Version '1.1.1a' '1.1.1b' | Should -Be 1
        Compare-Version '2019-01-01' '2019-01-02' | Should -Be 1
        Compare-Version '2019-01-02' '2019-01-01' | Should -Be -1
        Compare-Version '2018-01-01' '2019-01-01' | Should -Be 1
        Compare-Version '2019-01-01' '2018-01-01' | Should -Be -1
    }

    it 'handles comparsion against en empty string' {
        Compare-Version '7.0.4-9' '' | Should -Be -1
    }

    it 'handles equal versions' {
        Compare-Version '12.0' '12.0' | Should -Be 0
        Compare-Version '7.0.4-9' '7.0.4-9' | Should -Be 0
    }
}
