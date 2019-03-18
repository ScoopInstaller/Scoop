. "$psscriptroot\..\lib\core.ps1"

describe "hashtable" -Tag 'Scoop' {
    $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 }, "five": true, "six": false, "seven": "\/Date(1529917395805)\/", "eight": "2019-03-18T15:22:09.3930000+01:00" }'

    it "converts pscustomobject to hashtable" {
        $obj = ConvertFrom-Json $json

        $obj.one | should -beexactly 1
        $obj.two[0].a | should -be "a"
        $obj.two[1] | should -be "b"
        $obj.two[2] | should -beexactly 2
        $obj.three.four | should -beexactly 4
        $obj.five | should -beexactly $true
        $obj.six | should -beexactly $false
        [System.DateTime]::Equals($obj.seven, $(New-Object System.DateTime (2018, 06, 25, 09, 03, 15, 805))) | should -betrue
        [System.DateTime]::Equals([System.DateTime]::parse($obj.eight), $(New-Object System.DateTime (2019, 03, 18, 15, 22, 09, 393))) | should -betrue
    }
}
