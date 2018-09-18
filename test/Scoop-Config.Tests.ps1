. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\config.ps1"

describe "hashtable" -Tag 'Scoop' {
    $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 }, "five": true, "six": false, "seven": "\/Date(1529917395805)\/" }'

    it "converts pscustomobject to hashtable" {
        $obj = convertfrom-json $json
        $ht = hashtable $obj

        $ht.one | should beexactly 1
        $ht.two[0].a | should be "a"
        $ht.two[1] | should be "b"
        $ht.two[2] | should beexactly 2
        $ht.three.four | should beexactly 4
        $ht.five | should beexactly $true
        $ht.six | should beexactly $false
        [System.DateTime]::Equals($ht.seven, $(New-Object System.DateTime (2018, 06, 25, 09, 03, 15, 805))) | should be $true
    }
}
