BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\decompress.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\versions.ps1"
}

Describe 'Decompression function' -Tag 'Scoop', 'Windows', 'Decompress' {

    BeforeAll {
        $working_dir = setup_working 'decompress'

        function test_extract($extract_fn, $from, $removal) {
            $to = (strip_ext $from) -replace '\.tar$', ''
            & $extract_fn ($from -replace '/', '\') ($to -replace '/', '\') -Removal:$removal
            return $to
        }

    }
    Context 'Decompression test cases should exist' {
        BeforeAll {
            $testcases = "$working_dir\TestCases.zip"
        }
        It 'Test cases should exist and hash should match' {
            $testcases | Should -Exist
            (Get-FileHash -Path $testcases -Algorithm SHA256).Hash.ToLower() | Should -Be '791bfce192917a2ff225dcdd87d23ae5f720b20178d85e68e4b1b56139cf8e6a'
        }
        It 'Test cases should be extracted correctly' {
            { Microsoft.PowerShell.Archive\Expand-Archive -Path $testcases -DestinationPath $working_dir } | Should -Not -Throw
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

        It 'extract normal compressed file' {
            $to = test_extract 'Expand-7zipArchive' $test1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract nested compressed file' {
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

        It 'extract nested compressed file with different inner name' {
            $to = test_extract 'Expand-7zipArchive' $test4
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract splited 7z archives (.001, .002, ...)' {
            $to = test_extract 'Expand-7zipArchive' $test5_1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract splited RAR archives (.part01.rar, .part02.rar, ...)' {
            $to = test_extract 'Expand-7zipArchive' $test6_1
            $to | Should -Exist
            "$to\dummy" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
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

        It 'extract normal compressed file' {
            $to = test_extract 'Expand-ZstdArchive' $test1
            $to | Should -Exist
            "$to\ZstdTest" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'extract nested compressed file' {
            $to = test_extract 'Expand-ZstdArchive' $test2
            $to | Should -Exist
            "$to\ZstdTest" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
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

        It 'extract normal MSI file' {
            Mock get_config { $false }
            $to = test_extract 'Expand-MsiArchive' $test1
            $to | Should -Exist
            "$to\MSITest\empty" | Should -Exist
            (Get-ChildItem "$to\MSITest").Count | Should -Be 1
        }

        It 'extract empty MSI file using lessmsi' {
            Mock get_config { $true }
            $to = test_extract 'Expand-MsiArchive' $test2
            $to | Should -Exist
        }

        It 'works with "-Removal" switch ($removal param)' {
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

        It 'extract Inno Setup file' {
            $to = test_extract 'Expand-InnoArchive' $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
            $test | Should -Exist
            test_extract 'Expand-InnoArchive' $test $true
            $test | Should -Not -Exist
        }
    }

    Context 'zip extraction' {

        BeforeAll {
            $test = "$working_dir\ZipTest.zip"
        }

        It 'extract compressed file' {
            $to = test_extract 'Expand-ZipArchive' $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
            $test | Should -Exist
            test_extract 'Expand-ZipArchive' $test $true
            $test | Should -Not -Exist
        }
    }
}
