. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\config.ps1"

describe "hashtable" {
    $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 } }'

    it "converts pscustomobject to hashtable" {
        $obj = convertfrom-json $json
        $ht = hashtable $obj

        $ht.one | should beexactly 1
        $ht.two[0].a | should be "a"
        $ht.two[1] | should be "b"
        $ht.two[2] | should beexactly 2
        $ht.three.four | should beexactly 4
    }
}
