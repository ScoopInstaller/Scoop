."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\install.ps1"
."$psscriptroot\..\lib\unix.ps1"
."$psscriptroot\Scoop-TestLib.ps1"

$repo_dir = (Get-Item $MyInvocation.mycommand.path).Directory.Parent.FullName
$isUnix = is_unix

Describe "is_directory" {
  BeforeAll {
    $working_dir = setup_working "is_directory"
  }

  It "is_directory recognize directories" {
    is_directory "$working_dir\i_am_a_directory" | Should be $true
  }
  It "is_directory recognize files" {
    is_directory "$working_dir\i_am_a_file.txt" | Should be $false
  }

  It "is_directory is falsey on unknown path" {
    is_directory "$working_dir\i_do_not_exist" | Should be $false
  }
}

Describe "movedir" {
  $extract_dir = "subdir"
  $extract_to = $null

  BeforeAll {
    $working_dir = setup_working "movedir"
  }

  It "moves directories with no spaces in path" -skip:$isUnix {
    $dir = "$working_dir\user"
    movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

    "$dir\test.txt" | Should FileContentMatch "this is the one"
    "$dir\_tmp\$extract_dir" | Should not exist
  }

  It "moves directories with spaces in path" -skip:$isUnix {
    $dir = "$working_dir\user with space"
    movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

    "$dir\test.txt" | Should FileContentMatch "this is the one"
    "$dir\_tmp\$extract_dir" | Should not exist

    # test trailing \ in from dir
    movedir "$dir\_tmp\$null" "$dir\another"
    "$dir\another\test.txt" | Should FileContentMatch "testing"
    "$dir\_tmp" | Should not exist
  }

  It "moves directories with quotes in path" -skip:$isUnix {
    $dir = "$working_dir\user with 'quote"
    movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

    "$dir\test.txt" | Should FileContentMatch "this is the one"
    "$dir\_tmp\$extract_dir" | Should not exist
  }
}

Describe "unzip_old" {
  BeforeAll {
    $working_dir = setup_working "unzip_old"
  }

  function test-unzip ($from) {
    $to = strip_ext $from

    if (is_unix) {
      unzip_old ($from -replace '\\','/') ($to -replace '\\','/')
    } else {
      unzip_old ($from -replace '/','\') ($to -replace '/','\')
    }

    $to
  }

  Context "zip file size is zero bytes" {
    $zerobyte = "$working_dir\zerobyte.zip"
    $zerobyte | Should exist

    It "unzips file with zero bytes without error" -skip:$isUnix {
      # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
      # `$to = test-unzip $zerobyte` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
      $to = ([string](test-unzip $zerobyte)).trimStart()

      $to | Should not match '^\s'
      $to | Should not be NullOrEmpty

      $to | Should exist

      (Get-ChildItem $to).count | Should be 0
    }
  }

  Context "zip file is small in size" {
    $small = "$working_dir\small.zip"
    $small | Should exist

    It "unzips file which is small in size" -skip:$isUnix {
      # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
      # `$to = test-unzip $small` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
      $to = ([string](test-unzip $small)).trimStart()

      $to | Should not match '^\s'
      $to | Should not be NullOrEmpty

      $to | Should exist

      # these don't work for some reason on appveyor
      #join-path $to "empty" | should exist
      #(gci $to).count | should be 1
    }
  }
}

Describe "shim" {
  BeforeAll {
    $working_dir = setup_working "shim"
    $shimdir = shimdir
    $(ensure_in_path $shimdir) | Out-Null
  }

  It "links a file onto the user's path" -skip:$isUnix {
    { Get-Command "shim-test" -ea stop } | Should throw
    { Get-Command "shim-test.ps1" -ea stop } | Should throw
    { Get-Command "shim-test.cmd" -ea stop } | Should throw
    { shim-test } | Should throw

    shim "$working_dir\shim-test.ps1" $false "shim-test"
    { Get-Command "shim-test" -ea stop } | Should not throw
    { Get-Command "shim-test.ps1" -ea stop } | Should not throw
    { Get-Command "shim-test.cmd" -ea stop } | Should not throw
    shim-test | Should be "Hello, world!"
  }

  Context "user with quote" {
    It "shims a file with quote in path" -skip:$isUnix {
      { Get-Command "shim-test" -ea stop } | Should throw
      { shim-test } | Should throw

      shim "$working_dir\user with 'quote\shim-test.ps1" $false "shim-test"
      { Get-Command "shim-test" -ea stop } | Should not throw
      shim-test | Should be "Hello, world!"
    }
  }

  AfterEach {
    rm_shim "shim-test" $shimdir
  }
}

Describe "rm_shim" {
  BeforeAll {
    $working_dir = setup_working "shim"
    $shimdir = shimdir
    $(ensure_in_path $shimdir) | Out-Null
  }

  It "removes shim from path" -skip:$isUnix {
    shim "$working_dir\shim-test.ps1" $false "shim-test"

    rm_shim "shim-test" $shimdir

    { Get-Command "shim-test" -ea stop } | Should throw
    { Get-Command "shim-test.ps1" -ea stop } | Should throw
    { Get-Command "shim-test.cmd" -ea stop } | Should throw
    { shim-test } | Should throw
  }
}

Describe "ensure_robocopy_in_path" {
  $shimdir = shimdir $false
  Mock versiondir { $repo_dir }

  BeforeAll {
    reset_aliases
  }

  Context "robocopy is not in path" {
    It "shims robocopy when not on path" -skip:$isUnix {
      Mock Get-Command { $false }
      Get-Command robocopy | Should be $false

      ensure_robocopy_in_path

      "$shimdir/robocopy.ps1" | Should exist
      "$shimdir/robocopy.exe" | Should exist

      # clean up
      rm_shim robocopy $(shimdir $false) | Out-Null
    }
  }

  Context "robocopy is in path" {
    It "does not shim robocopy when it is in path" -skip:$isUnix {
      Mock Get-Command { $true }
      ensure_robocopy_in_path

      "$shimdir/robocopy.ps1" | Should not exist
      "$shimdir/robocopy.exe" | Should not exist
    }
  }
}

Describe 'sanitary_path' {
  It 'removes invalid path characters from a string' {
    $path = 'test?.json'
    $valid_path = sanitary_path $path

    $valid_path | Should be "test.json"
  }
}

Describe 'app' {
  It 'parses the bucket name from an app query' {
    $query = "test"
    $app,$bucket = app $query
    $app | Should be "test"
    $bucket | Should be $null

    $query = "extras/enso"
    $app,$bucket = app $query
    $app | Should be "enso"
    $bucket | Should be "extras"

    $query = "test-app"
    $app,$bucket = app $query
    $app | Should be "test-app"
    $bucket | Should be $null

    $query = "test-bucket/test-app"
    $app,$bucket = app $query
    $app | Should be "test-app"
    $bucket | Should be "test-bucket"
  }
}
