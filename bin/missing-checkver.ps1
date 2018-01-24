# list manifests which do not specify a checkver regex
param(
  [string]$dir,
  [switch]$skipSupported = $false
)

."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\manifest.ps1"

if (!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = Resolve-Path $dir

Write-Host "[" -NoNewline
Write-Host -f green "C" -NoNewline
Write-Host "]heckver"
Write-Host " | [" -NoNewline
Write-Host -f cyan "A" -NoNewline
Write-Host "]utoupdate"
Write-Host " |  |"

Get-ChildItem $dir "*.json" | ForEach-Object {
  $json = parse_json "$dir\$_"

  if ($skipSupported -and $json.checkver -and $json.autoupdate) {
    return
  }

  Write-Host "[" -NoNewline
  Write-Host -f green -NoNewline $(if ($json.checkver) { "C" } else { " " })
  Write-Host "]" -NoNewline

  Write-Host "[" -NoNewline
  Write-Host -f cyan -NoNewline $(if ($json.autoupdate) { "A" } else { " " })
  Write-Host "] " -NoNewline
  Write-Host (strip_ext $_)
}
