. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\unix.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

$isUnix = is_unix

function test_extract($extract_fn, $from, $removal) {
    $to = (strip_ext $from) -replace '\.tar$', ''
    & $extract_fn ($from -replace '/', '\') ($to -replace '/', '\') -Removal:$removal
    return $to
}

Describe 'Decompression function' -Tag 'Scoop', 'Decompress' {
    BeforeAll {
        $working_dir = setup_working 'decompress'

        It "Decompression test cases should exist" {
            $testcases = "$working_dir\TestCases.zip"
            $testcases | Should -Exist
            compute_hash $testcases 'sha256' | Should -Be '900b6e05275ad11a57dad85ffac6d9b4995657956a980bb1eae12c173f34a280'
            if (!$isUnix) {
                Microsoft.PowerShell.Archive\Expand-Archive $testcases $working_dir
            }
        }
    }

    Context "7zip extraction" {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { (Get-Command 7z.exe).Path }
            } elseif (!(installed 7zip)) {
                scoop install 7zip
            }
            $test1 = "$working_dir\7ZipTest1.7z"
            $test2 = "$working_dir\7ZipTest2.tgz"
            $test3 = "$working_dir\7ZipTest3.tar.bz2"
            $test4 = "$working_dir\7ZipTest4.tar.gz"
        }

        It "extract normal compressed file" -Skip:$isUnix {
            $to = test_extract "Expand-7zipArchive" $test1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "extract nested compressed file" -Skip:$isUnix {
            # file ext: tgz
            $to = test_extract "Expand-7zipArchive" $test2
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1

            # file ext: tar.bz2
            $to = test_extract "Expand-7zipArchive" $test3
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "extract nested compressed file with different inner name" -Skip:$isUnix {
            $to = test_extract "Expand-7zipArchive" $test4
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '-Removal' switch (`$removal param)" -Skip:$isUnix {
            $test1 | Should -Exist
            test_extract "Expand-7zipArchive" $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context "zstd extraction" {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:zstd }
            } elseif (!(installed zstd)) {
                scoop install zstd
            }

            $test1 = "$working_dir\ZstdTest.zst"
            $test2 = "$working_dir\ZstdTest.tar.zst"
        }

        It "extract normal compressed file" -Skip:$isUnix {
            $to = test_extract "Expand-ZstdArchive" $test1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "extract nested compressed file" -Skip:$isUnix {
            $to = test_extract "Expand-7zipArchive" $test2
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '-Removal' switch (`$removal param)" -Skip:$isUnix {
            $test1 | Should -Exist
            test_extract "Expand-ZstdArchive" $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context "msi extraction" {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:lessmsi }
            } elseif (!(installed lessmsi)) {
                scoop install lessmsi
            }
            $test1 = "$working_dir\MSITest.msi"
            $test2 = "$working_dir\MSITestNull.msi"
        }

        It "extract normal MSI file" -Skip:$isUnix {
            Mock get_config { $false }
            $to = test_extract "Expand-MsiArchive" $test1
            $to | Should -Exist
            "$to\MSITest\empty" | Should -Exist
            (Get-ChildItem "$to\MSITest").Count | Should -Be 1
        }

        It "extract empty MSI file using lessmsi" -Skip:$isUnix {
            Mock get_config { $true }
            $to = test_extract "Expand-MsiArchive" $test2
            $to | Should -Exist
        }

        It "works with '-Removal' switch (`$removal param)" -Skip:$isUnix {
            Mock get_config { $false }
            $test1 | Should -Exist
            test_extract "Expand-MsiArchive" $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context "inno extraction" {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:innounp }
            } elseif (!(installed innounp)) {
                scoop install innounp
            }
            $test = "$working_dir\InnoTest.exe"
        }

        It "extract Inno Setup file" -Skip:$isUnix {
            $to = test_extract "Expand-InnoArchive" $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '-Removal' switch (`$removal param)" -Skip:$isUnix {
            $test | Should -Exist
            test_extract "Expand-InnoArchive" $test $true
            $test | Should -Not -Exist
        }
    }

    Context "zip extraction" {

        BeforeAll {
            $test = "$working_dir\ZipTest.zip"
        }

        It "extract compressed file" -Skip:$isUnix {
            $to = test_extract "Expand-ZipArchive" $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '-Removal' switch (`$removal param)" -Skip:$isUnix {
            $test | Should -Exist
            test_extract "Expand-ZipArchive" $test $true
            $test | Should -Not -Exist
        }
    }
}
