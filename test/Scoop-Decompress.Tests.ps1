. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\decompress.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"
. "$PSScriptRoot\..\lib\versions.ps1"
. "$PSScriptRoot\..\lib\unix.ps1"

$isUnix = is_unix

Describe 'Decompression function' -Tag 'Scoop', 'Decompress' {

    BeforeAll {
        $working_dir = setup_working 'decompress'

        function test_extract($extract_fn, $from, $removal) {
            $to = (strip_ext $from) -replace '\.tar$', ''
            & $extract_fn ($from -replace '/', '\') ($to -replace '/', '\') -Removal:$removal
            return $to
        }

        It 'Decompression test cases should exist' {
            $testcases = "$working_dir\TestCases.zip"
            $testcases | Should -Exist
            compute_hash $testcases 'sha256' | Should -Be '791bfce192917a2ff225dcdd87d23ae5f720b20178d85e68e4b1b56139cf8e6a'
            if (!$isUnix) {
                Microsoft.PowerShell.Archive\Expand-Archive $testcases $working_dir
            }
        }
    }

    Context '7zip extraction' {

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
            $test5_1 = "$working_dir\7ZipTest5.7z.001"
            $test5_2 = "$working_dir\7ZipTest5.7z.002"
            $test5_3 = "$working_dir\7ZipTest5.7z.003"
            $test6_1 = "$working_dir\7ZipTest6.part01.rar"
            $test6_2 = "$working_dir\7ZipTest6.part02.rar"
            $test6_3 = "$working_dir\7ZipTest6.part03.rar"
        }

        It 'extract normal compressed file' -Skip:$isUnix {
            $to = test_extract 'Expand-7zipArchive' $test1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract nested compressed file' -Skip:$isUnix {
            # file ext: tgz
            $to = test_extract 'Expand-7zipArchive' $test2
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1

            # file ext: tar.bz2
            $to = test_extract 'Expand-7zipArchive' $test3
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract nested compressed file with different inner name' -Skip:$isUnix {
            $to = test_extract 'Expand-7zipArchive' $test4
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract splited 7z archives (.001, .002, ...)' -Skip:$isUnix {
            $to = test_extract 'Expand-7zipArchive' $test5_1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract splited RAR archives (.part01.rar, .part02.rar, ...)' -Skip:$isUnix {
            $to = test_extract 'Expand-7zipArchive' $test6_1
            $to | Should -Exist
            "$to\dummy" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' -Skip:$isUnix {
            $test1 | Should -Exist
            test_extract 'Expand-7zipArchive' $test1 $true
            $test1 | Should -Not -Exist
            $test5_1 | Should -Exist
            $test5_2 | Should -Exist
            $test5_3 | Should -Exist
            test_extract 'Expand-7zipArchive' $test5_1 $true
            $test5_1 | Should -Not -Exist
            $test5_2 | Should -Not -Exist
            $test5_3 | Should -Not -Exist
            $test6_1 | Should -Exist
            $test6_2 | Should -Exist
            $test6_3 | Should -Exist
            test_extract 'Expand-7zipArchive' $test6_1 $true
            $test6_1 | Should -Not -Exist
            $test6_2 | Should -Not -Exist
            $test6_3 | Should -Not -Exist
        }
    }

    Context 'zstd extraction' {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:SCOOP_ZSTD_PATH } -ParameterFilter { $Helper -eq 'zstd' }
                Mock Get-AppFilePath { '7z.exe' } -ParameterFilter { $Helper -eq '7zip' }
            } elseif (!(installed zstd)) {
                scoop install zstd
            }

            $test1 = "$working_dir\ZstdTest.zst"
            $test2 = "$working_dir\ZstdTest.tar.zst"
        }

        It 'extract normal compressed file' -Skip:$isUnix {
            $to = test_extract 'Expand-ZstdArchive' $test1
            $to | Should -Exist
            "$to\ZstdTest" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract nested compressed file' -Skip:$isUnix {
            $to = test_extract 'Expand-ZstdArchive' $test2
            $to | Should -Exist
            "$to\ZstdTest" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' -Skip:$isUnix {
            $test1 | Should -Exist
            test_extract 'Expand-ZstdArchive' $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context 'msi extraction' {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:SCOOP_LESSMSI_PATH }
            } elseif (!(installed lessmsi)) {
                scoop install lessmsi
            }
            $test1 = "$working_dir\MSITest.msi"
            $test2 = "$working_dir\MSITestNull.msi"
        }

        It 'extract normal MSI file' -Skip:$isUnix {
            Mock get_config { $false }
            $to = test_extract 'Expand-MsiArchive' $test1
            $to | Should -Exist
            "$to\MSITest\empty" | Should -Exist
            (Get-ChildItem "$to\MSITest").Count | Should -Be 1
        }

        It 'extract empty MSI file using lessmsi' -Skip:$isUnix {
            Mock get_config { $true }
            $to = test_extract 'Expand-MsiArchive' $test2
            $to | Should -Exist
        }

        It 'works with "-Removal" switch ($removal param)' -Skip:$isUnix {
            Mock get_config { $false }
            $test1 | Should -Exist
            test_extract 'Expand-MsiArchive' $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context 'inno extraction' {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:SCOOP_INNOUNP_PATH }
            } elseif (!(installed innounp)) {
                scoop install innounp
            }
            $test = "$working_dir\InnoTest.exe"
        }

        It 'extract Inno Setup file' -Skip:$isUnix {
            $to = test_extract 'Expand-InnoArchive' $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' -Skip:$isUnix {
            $test | Should -Exist
            test_extract 'Expand-InnoArchive' $test $true
            $test | Should -Not -Exist
        }
    }

    Context 'zip extraction' {

        BeforeAll {
            $test = "$working_dir\ZipTest.zip"
        }

        It 'extract compressed file' -Skip:$isUnix {
            $to = test_extract 'Expand-ZipArchive' $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' -Skip:$isUnix {
            $test | Should -Exist
            test_extract 'Expand-ZipArchive' $test $true
            $test | Should -Not -Exist
        }
    }
}
