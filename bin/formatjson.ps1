# reformat manifest json
param($path)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\json.ps1"

if(!$path) { $path = "$psscriptroot\..\bucket" }
$path = resolve-path $path

$dir = ""
$type = Get-Item $path
if ($type -is [System.IO.DirectoryInfo]) {
    $dir = "$path\"
    $files = Get-ChildItem $path "*.json"
} elseif ($type -is [System.IO.FileInfo]) {
    $files = @($path)
} else {
    Write-Error "unknown item"
    exit
}

$files | ForEach-Object {
    # beautify
    $json = parse_json "$dir$_" | ConvertToPrettyJson

    # convert to 4 spaces
    $json = $json -replace "`t",'    '

    [System.IO.File]::WriteAllLines("$dir$_", $json)
}
