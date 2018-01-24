."$psscriptroot\Scoop-TestLib.ps1"
."$psscriptroot\..\lib\versions.ps1"

Describe "versions" {
  It 'compares versions with integer-string mismatch' {
    $a = '1.8.9'
    $b = '1.8.5-1'
    $res = compare_versions $a $b

    $res | Should be 1
  }

  It 'handles plain string version comparison to int version' {
    $a = 'latest'
    $b = '20150405'
    $res = compare_versions $a $b

    $res | Should be 1
  }

  It 'handles dashed version components' {
    $a = '7.0.4-9'
    $b = '7.0.4-10'

    $res = compare_versions $a $b

    $res | Should be -1
  }

  It 'handles comparsion against en empty string' {
    compare_versions '7.0.4-9' '' | Should be 1
  }

  It 'handles equal versions' {
    compare_versions '12.0' '12.0' | Should be 0
  }
}
