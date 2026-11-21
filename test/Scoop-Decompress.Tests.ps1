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
            & $extract_fn ($from -replace '/', '\') ($to -replace '/', '\') -Removal:$removal -ExtractDir $args[0]
            return $to
        }

    }
    Context 'Decompression test cases should exist' {
        BeforeAll {
            $testcases = "$working_dir\TestCases.zip"
        }
        It 'Test cases should exist and hash should match' {
            Test-Path $testcases | Should-BeTrue
            (Get-FileHash -Path $testcases -Algorithm SHA256).Hash.ToLower() | Should-Be '591072faabd419b77932b7023e5899b4e05c0bf8e6859ad367398e6bfe1eb203'
        }
        It 'Test cases should be extracted correctly' {
            & { Microsoft.PowerShell.Archive\Expand-Archive -Path $testcases -DestinationPath $working_dir }
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
            $test7 = "$working_dir\NSISTest.exe"
        }

        AfterEach {
            Remove-Item -Path $to -Recurse -Force
        }

        It 'extract normal compressed file' {
            $to = test_extract 'Expand-7zipArchive' $test1
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 4
        }

        It 'extract "extract_dir" correctly' {
            $to = test_extract 'Expand-7zipArchive' $test1 $false 'tmp'
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract "extract_dir" with spaces correctly' {
            $to = test_extract 'Expand-7zipArchive' $test1 $false 'tmp 2'
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract "extract_dir" with nested folder with same name' {
            $to = test_extract 'Expand-7zipArchive' $test1 $false 'keep\sub'
            Test-Path $to | Should-BeTrue
            Test-Path "$to\keep\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
            (Get-ChildItem "$to\keep").Count | Should-Be 1
        }

        It 'extract nested compressed file' {
            # file ext: tgz
            $to = test_extract 'Expand-7zipArchive' $test2
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1

            # file ext: tar.bz2
            $to = test_extract 'Expand-7zipArchive' $test3
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract nested compressed file with different inner name' {
            $to = test_extract 'Expand-7zipArchive' $test4
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract split 7z archives (.001, .002, ...)' {
            $to = test_extract 'Expand-7zipArchive' $test5_1
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract split RAR archives (.part01.rar, .part02.rar, ...)' {
            $to = test_extract 'Expand-7zipArchive' $test6_1
            Test-Path $to | Should-BeTrue
            Test-Path "$to\dummy" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'extract NSIS installer' {
            $to = test_extract 'Expand-7zipArchive' $test7
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'self-extract NSIS installer' {
            $to = "$working_dir\NSIS Test"
            $null = Invoke-ExternalCommand -FilePath $test7 -ArgumentList @('/S', '/NCRC', "/D=$to")
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
            Test-Path $test1 | Should-BeTrue
            $to = test_extract 'Expand-7zipArchive' $test1 $true
            Test-Path $to | Should-BeTrue
            Test-Path $test1 | Should-BeFalse
            Test-Path $test5_1 | Should-BeTrue
            Test-Path $test5_2 | Should-BeTrue
            Test-Path $test5_3 | Should-BeTrue
            $to = test_extract 'Expand-7zipArchive' $test5_1 $true
            Test-Path $to | Should-BeTrue
            Test-Path $test5_1 | Should-BeFalse
            Test-Path $test5_2 | Should-BeFalse
            Test-Path $test5_3 | Should-BeFalse
            Test-Path $test6_1 | Should-BeTrue
            Test-Path $test6_2 | Should-BeTrue
            Test-Path $test6_3 | Should-BeTrue
            $to = test_extract 'Expand-7zipArchive' $test6_1 $true
            Test-Path $to | Should-BeTrue
            Test-Path $test6_1 | Should-BeFalse
            Test-Path $test6_2 | Should-BeFalse
            Test-Path $test6_3 | Should-BeFalse
        }
    }

    Context 'msi extraction' {

        BeforeAll {
            if ($env:CI) {
                Mock Get-AppFilePath { $env:SCOOP_LESSMSI_PATH }
            } elseif (!(installed lessmsi)) {
                scoop install lessmsi
            }
            Copy-Item "$working_dir\MSITest.msi" "$working_dir\MSI Test.msi"
            $test1 = "$working_dir\MSITest.msi"
            $test2 = "$working_dir\MSI Test.msi"
            $test3 = "$working_dir\MSITestNull.msi"
        }

        It 'extract normal MSI file using msiexec' {
            Mock get_config { $false }
            $to = test_extract 'Expand-MsiArchive' $test1
            Test-Path $to | Should-BeTrue
            Test-Path "$to\MSITest\empty" | Should-BeTrue
            (Get-ChildItem "$to\MSITest").Count | Should-Be 1
        }

        It 'extract normal MSI file with whitespace in path using msiexec' {
            Mock get_config { $false }
            $to = test_extract 'Expand-MsiArchive' $test2
            Test-Path $to | Should-BeTrue
            Test-Path "$to\MSITest\empty" | Should-BeTrue
            (Get-ChildItem "$to\MSITest").Count | Should-Be 1
        }

        It 'extract normal MSI file using lessmsi' {
            Mock get_config { $true }
            $to = test_extract 'Expand-MsiArchive' $test1
            Test-Path $to | Should-BeTrue
        }

        It 'extract normal MSI file with whitespace in path using lessmsi' {
            Mock get_config { $true }
            $to = test_extract 'Expand-MsiArchive' $test2
            Test-Path $to | Should-BeTrue
        }

        It 'extract empty MSI file using lessmsi' {
            Mock get_config { $true }
            $to = test_extract 'Expand-MsiArchive' $test3
            Test-Path $to | Should-BeTrue
        }

        It 'works with "-Removal" switch ($removal param)' {
            Mock get_config { $false }
            Test-Path $test1 | Should-BeTrue
            test_extract 'Expand-MsiArchive' $test1 $true
            Test-Path $test1 | Should-BeFalse
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
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
            Test-Path $test | Should-BeTrue
            test_extract 'Expand-InnoArchive' $test $true
            Test-Path $test | Should-BeFalse
        }
    }

    Context 'zip extraction' {

        BeforeAll {
            $test = "$working_dir\ZipTest.zip"
        }

        It 'extract compressed file' {
            $to = test_extract 'Expand-ZipArchive' $test
            Test-Path $to | Should-BeTrue
            Test-Path "$to\empty" | Should-BeTrue
            (Get-ChildItem $to).Count | Should-Be 1
        }

        It 'works with "-Removal" switch ($removal param)' {
            Test-Path $test | Should-BeTrue
            test_extract 'Expand-ZipArchive' $test $true
            Test-Path $test | Should-BeFalse
        }
    }
}
