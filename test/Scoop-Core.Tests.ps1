. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\unix.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName
$isUnix = is_unix

describe "Get-AppFilePath" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "is_directory"
        Mock versiondir { 'local' } -Verifiable -ParameterFilter { $global -eq $false }
        Mock versiondir { 'global' } -Verifiable -ParameterFilter { $global -eq $true }
    }

    it "should return locally installed program" {
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq 'local\i_am_a_file.txt' }
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq 'global\i_am_a_file.txt' }
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should -Be 'local\i_am_a_file.txt'
    }

    it "should return globally installed program" {
        Mock Test-Path { $false } -Verifiable -ParameterFilter { $Path -eq 'local\i_am_a_file.txt' }
        Mock Test-Path { $true } -Verifiable -ParameterFilter { $Path -eq 'global\i_am_a_file.txt' }
        Get-AppFilePath -App 'is_directory' -File 'i_am_a_file.txt' | Should -Be 'global\i_am_a_file.txt'
    }

    it "should return null if program is not installed" {
        Get-AppFilePath -App 'is_directory' -File 'i_do_not_exist' | Should -BeNullOrEmpty
    }

    it "should throw if parameter is wrong or missing" {
        { Get-AppFilePath -App 'is_directory' -File } | Should -Throw
        { Get-AppFilePath -App -File 'i_am_a_file.txt' } | Should -Throw
        { Get-AppFilePath -App -File } | Should -Throw
    }
}

describe "Get-HelperPath" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "is_directory"
    }
    it "should return path if program is installed" {
        Mock Get-AppFilePath { '7zip\current\7z.exe' }
        Get-HelperPath -Helper 7zip | Should -Be '7zip\current\7z.exe'
    }

    it "should return null if program is not installed" {
        Mock Get-AppFilePath { $null }
        Get-HelperPath -Helper 7zip | Should -BeNullOrEmpty
    }

    it "should throw if parameter is wrong or missing" {
        { Get-HelperPath -Helper } | Should -Throw
        { Get-HelperPath -Helper Wrong } | Should -Throw
    }
}


describe "Test-HelperInstalled" -Tag 'Scoop' {
    it "should return true if program is installed" {
        Mock Get-HelperPath { '7z.exe' }
        Test-HelperInstalled -Helper 7zip | Should -BeTrue
    }

    it "should return false if program is not installed" {
        Mock Get-HelperPath { $null }
        Test-HelperInstalled -Helper 7zip | Should -BeFalse
    }

    it "should throw if parameter is wrong or missing" {
        { Test-HelperInstalled -Helper } | Should -Throw
        { Test-HelperInstalled -Helper Wrong } | Should -Throw
    }
}

describe "Test-Aria2Enabled" -Tag 'Scoop' {
    it "should return true if aria2 is installed" {
        Mock Test-HelperInstalled { $true }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeTrue
    }

    it "should return false if aria2 is not installed" {
        Mock Test-HelperInstalled { $false }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $false }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $true }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse
    }
}

describe "Test-CommandAvailable" -Tag 'Scoop' {
    it "should return true if command exists" {
        Test-CommandAvailable 'Write-Host' | Should -BeTrue
    }

    it "should return false if command doesn't exist" {
        Test-CommandAvailable 'Write-ThisWillProbablyNotExist' | Should -BeFalse
    }

    it "should throw if parameter is wrong or missing" {
        { Test-CommandAvailable } | Should -Throw
    }
}


describe "is_directory" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "is_directory"
    }

    it "is_directory recognize directories" {
        is_directory "$working_dir\i_am_a_directory" | should -be $true
    }
    it "is_directory recognize files" {
        is_directory "$working_dir\i_am_a_file.txt" | should -be $false
    }

    it "is_directory is falsey on unknown path" {
        is_directory "$working_dir\i_do_not_exist" | should -be $false
    }
}

describe "movedir" -Tag 'Scoop' {
    $extract_dir = "subdir"
    $extract_to = $null

    beforeall {
        $working_dir = setup_working "movedir"
    }

    it "moves directories with no spaces in path" -skip:$isUnix {
        $dir = "$working_dir\user"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should -FileContentMatch "this is the one"
        "$dir\_tmp\$extract_dir" | should -not -exist
    }

    it "moves directories with spaces in path" -skip:$isUnix {
        $dir = "$working_dir\user with space"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should -FileContentMatch "this is the one"
        "$dir\_tmp\$extract_dir" | should -not -exist

        # test trailing \ in from dir
        movedir "$dir\_tmp\$null" "$dir\another"
        "$dir\another\test.txt" | should -FileContentMatch "testing"
        "$dir\_tmp" | should -not -exist
    }

    it "moves directories with quotes in path" -skip:$isUnix {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should -FileContentMatch "this is the one"
        "$dir\_tmp\$extract_dir" | should -not -exist
    }
}

describe "shim" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "links a file onto the user's path" -skip:$isUnix {
        { get-command "shim-test" -ea stop } | should -throw
        { get-command "shim-test.ps1" -ea stop } | should -throw
        { get-command "shim-test.cmd" -ea stop } | should -throw
        { shim-test } | should -throw

        shim "$working_dir\shim-test.ps1" $false "shim-test"
        { get-command "shim-test" -ea stop } | should -not -throw
        { get-command "shim-test.ps1" -ea stop } | should -not -throw
        { get-command "shim-test.cmd" -ea stop } | should -not -throw
        shim-test | should -be "Hello, world!"
    }

    context "user with quote" {
        it "shims a file with quote in path" -skip:$isUnix {
            { get-command "shim-test" -ea stop } | should -throw
            { shim-test } | should -throw

            shim "$working_dir\user with 'quote\shim-test.ps1" $false "shim-test"
            { get-command "shim-test" -ea stop } | should -not -throw
            shim-test | should -be "Hello, world!"
        }
    }

    aftereach {
        rm_shim "shim-test" $shimdir
    }
}

describe "rm_shim" -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "removes shim from path" -skip:$isUnix {
        shim "$working_dir\shim-test.ps1" $false "shim-test"

        rm_shim "shim-test" $shimdir

        { get-command "shim-test" -ea stop } | should -throw
        { get-command "shim-test.ps1" -ea stop } | should -throw
        { get-command "shim-test.cmd" -ea stop } | should -throw
        { shim-test } | should -throw
    }
}

Describe "get_app_name_from_shim" -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | Out-Null
    }

    It "returns empty string if file does not exist" -skip:$isUnix {
        get_app_name_from_shim "non-existent-file" | should -be ""
    }

    It "returns app name if file exists and is a shim to an app" -skip:$isUnix {
        mkdir -p "$working_dir/mockapp/current/"
        Write-Output "" | Out-File "$working_dir/mockapp/current/mockapp.ps1"
        shim "$working_dir/mockapp/current/mockapp.ps1" $false "shim-test"
        $shim_path = (get-command "shim-test.ps1").Path
        get_app_name_from_shim "$shim_path" | should -be "mockapp"
    }

    It "returns empty string if file exists and is not a shim" -skip:$isUnix {
        Write-Output "lorem ipsum" | Out-File -Encoding ascii "$working_dir/mock-shim.ps1"
        get_app_name_from_shim "$working_dir/mock-shim.ps1" | should -be ""
    }

    AfterEach {
        if (Get-Command "shim-test" -ErrorAction SilentlyContinue) {
            rm_shim "shim-test" $shimdir -ErrorAction SilentlyContinue
        }
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue "$working_dir/mockapp"
        Remove-Item -Force -ErrorAction SilentlyContinue "$working_dir/moch-shim.ps1"
    }
}

describe "ensure_robocopy_in_path" -Tag 'Scoop' {
    $shimdir = shimdir $false
    mock versiondir { $repo_dir }

    beforeall {
        reset_aliases
    }

    context "robocopy is not in path" {
        it "shims robocopy when not on path" -skip:$isUnix {
            mock Test-CommandAvailable { $false }
            Test-CommandAvailable robocopy | should -be $false

            ensure_robocopy_in_path

            # "$shimdir/robocopy.ps1" | should -exist
            "$shimdir/robocopy.exe" | should -exist

            # clean up
            rm_shim robocopy $(shimdir $false) | out-null
        }
    }

    context "robocopy is in path" {
        it "does not shim robocopy when it is in path" -skip:$isUnix {
            mock Test-CommandAvailable { $true }
            Test-CommandAvailable robocopy | should -be $true

            ensure_robocopy_in_path

            # "$shimdir/robocopy.ps1" | should -not -exist
            "$shimdir/robocopy.exe" | should -not -exist
        }
    }
}

describe 'sanitary_path' -Tag 'Scoop' {
  it 'removes invalid path characters from a string' {
    $path = 'test?.json'
    $valid_path = sanitary_path $path

    $valid_path | should -be "test.json"
  }
}

describe 'app' -Tag 'Scoop' {
    it 'parses the bucket name from an app query' {
        $query = "C:\test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be "C:\test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = ".\test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be ".\test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "..\test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be "..\test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "\\share\test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be "\\share\test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "https://example.com/test.json"
        $app, $bucket, $version = parse_app $query
        $app | should -be "https://example.com/test.json"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "test"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "extras/enso"
        $app, $bucket, $version = parse_app $query
        $app | should -be "enso"
        $bucket | should -be "extras"
        $version | should -benullorempty

        $query = "test-app"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test-app"
        $bucket | should -benullorempty
        $version | should -benullorempty

        $query = "test-bucket/test-app"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test-app"
        $bucket | should -be "test-bucket"
        $version | should -benullorempty

        $query = "test-bucket/test-app@1.8.0"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test-app"
        $bucket | should -be "test-bucket"
        $version | should -be "1.8.0"

        $query = "test-bucket/test-app@1.8.0-rc2"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test-app"
        $bucket | should -be "test-bucket"
        $version | should -be "1.8.0-rc2"

        $query = "test-bucket/test_app"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test_app"
        $bucket | should -be "test-bucket"
        $version | should -benullorempty

        $query = "test-bucket/test_app@1.8.0"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test_app"
        $bucket | should -be "test-bucket"
        $version | should -be "1.8.0"

        $query = "test-bucket/test_app@1.8.0-rc2"
        $app, $bucket, $version = parse_app $query
        $app | should -be "test_app"
        $bucket | should -be "test-bucket"
        $version | should -be "1.8.0-rc2"
    }
}
