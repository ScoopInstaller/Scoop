. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\unix.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\config.ps1"

$isUnix = is_unix

function install_app_ci($app, $architecture) {
    $manifest = manifest $app
    $version = $manifest.version
    $dir = ensure (versiondir $app $version)
    $fname = dl_urls $app $version $manifest $null $architecture $dir
    $dir = link_current $dir
    success "'$app' ($version) was installed successfully!"
}

function test_extract($extract_fn, $from, $recurse) {
    $to = (strip_ext $from) -replace '\.tar$', ''
    & $extract_fn ($from -replace '/', '\') ($to -replace '/', '\') $recurse | Out-Null
    $to
}

Describe "Decompression function" -Tag 'Scoop', 'Decompress' {
    BeforeAll {
        $working_dir = setup_working "decompress"
    }

    if (!$isUnix) {
        # Expanding Test Cases
        $testcases = "$working_dir\TestCases.zip"
        $testcases | Should -Exist
        compute_hash $testcases 'sha256' | Should -Be "695bb18cafda52644a19afd184b2545e9c48f1a191f7ff1efc26cb034587079c"
        extract_zip $testcases $working_dir
    }

    Context "7zip extraction" {

        if (!$isUnix) {
            install_app_ci 7zip 64bit
            $test1 = "$working_dir\7ZipTest1.7z"
            $test2 = "$working_dir\7ZipTest2.tgz"
            $test3 = "$working_dir\7ZipTest3.tar.bz2"
            $test4 = "$working_dir\7ZipTest4.tar.gz"
        }

        It "extract normal compressed file" -Skip:$isUnix {
            $to = test_extract "extract_7zip" $test1
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "extract nested compressed file" -Skip:$isUnix {
            # file ext: tgz
            $to = test_extract "extract_7zip" $test2
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1

            # file ext: tar.bz2
            $to = test_extract "extract_7zip" $test3
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "extract nested compressed file with different inner name" -Skip:$isUnix {
            $to = test_extract "extract_7zip" $test4
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '`$recurse' param" -Skip:$isUnix {
            $test1 | Should -Exist
            test_extract "extract_7zip" $test1 $true
            $test1 | Should -Not -Exist
        }
    }

    Context "zip extraction" {

        if (!$isUnix) {
            $test = "$working_dir\ZipTest.zip"
        }

        It "extract compressed file" -Skip:$isUnix {
            $to = test_extract "extract_zip" $test
            $to | Should -Exist
            "$to\empty" | Should -Exist
            (Get-ChildItem $to).Count | Should -Be 1
        }

        It "works with '`$recurse' param" -Skip:$isUnix {
            $test | Should -Exist
            test_extract "extract_zip" $test $true
            $test | Should -Not -Exist
        }
    }
}
