# list manifests which do not specify a checkver regex
param(
    [String]$dir,
    [Switch]$skipSupported = $false
)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

write-host "[" -nonewline
write-host -f green "C" -nonewline
write-host "]heckver"
write-host " | [" -nonewline
write-host -f cyan "A" -nonewline
write-host "]utoupdate"
write-host " |  |"

Get-ChildItem $dir "*.json" | ForEach-Object {
    $json = parse_json "$dir\$_"

    if ($skipSupported -and $json.checkver -and $json.autoupdate) {
        return
    }

    write-host "[" -nonewline
    write-host -f green -nonewline $( If ($json.checkver) {"C"} Else {" "} )
    write-host "]" -nonewline

    write-host "[" -nonewline
    write-host -f cyan -nonewline $( If ($json.autoupdate) {"A"} Else {" "} )
    write-host "] " -nonewline
    write-host (strip_ext $_)
}
