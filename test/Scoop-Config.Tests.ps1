."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\config.ps1"

Describe "hashtable" {
  $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 } }'

  It "converts pscustomobject to hashtable" {
    $obj = ConvertFrom-Json $json
    $ht = hashtable $obj

    $ht.One | Should beexactly 1
    $ht.two[0].a | Should be "a"
    $ht.two[1] | Should be "b"
    $ht.two[2] | Should beexactly 2
    $ht.three.four | Should beexactly 4
  }
}
