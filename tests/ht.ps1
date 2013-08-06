# testing converting json -> pscustomobject > hashtable

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\config.ps1"

$json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 } }'
$global:obj = convertfrom-json $json

$a = $obj.two[0]
#$a -is [pscustomobject]

$global:res = hashtable $obj