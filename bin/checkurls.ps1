# list manifests which do not specify a checkver regex
param(
  [string]$app,
  [string]$dir,
  [int]$timeout = 5
)

if (!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = Resolve-Path $dir

$search = "*"
if ($app) { $search = $app }

."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\manifest.ps1"
."$psscriptroot\..\lib\install.ps1"

if (!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = Resolve-Path $dir

# get apps to check
$queue = @()
Get-ChildItem $dir "$search.json" | ForEach-Object {
  $manifest = parse_json "$dir\$_"
  $queue +=,@( $_,$manifest)
}

$original = use_any_https_protocol

Write-Host "[" -NoNewline
Write-Host -f cyan "U" -NoNewline
Write-Host "]RLs"
Write-Host " | [" -NoNewline
Write-Host -f green "O" -NoNewline
Write-Host "]kay"
Write-Host " |  | [" -NoNewline
Write-Host -f red "F" -NoNewline
Write-Host "]ailed"
Write-Host " |  |  |"

function test_dl ($url,$cookies) {
  $wreq = [net.webrequest]::Create($url)
  $wreq.timeout = $timeout * 1000
  if ($wreq -is [net.httpwebrequest]) {
    $wreq.useragent = 'Scoop/1.0'
    $wreq.referer = strip_filename $url
    if ($cookies) {
      $wreq.headers.Add('Cookie',(cookie_header $cookies))
    }
  }
  $wres = $null
  try {
    $wres = $wreq.getresponse()
    return $url,$wres.statuscode,$null
  } catch {
    $e = $_.exception
    if ($e.innerexception) { $e = $e.innerexception }
    return $url,"Error",$e.message
  } finally {
    if ($wres -ne $null -and $wres -isnot [net.ftpwebresponse]) {
      $wres.close()
    }
  }
}

$queue | ForEach-Object {
  $name,$manifest = $_
  $urls = @()
  $ok = 0
  $failed = 0
  $errors = @()

  if ($manifest.url) {
    $manifest.url | ForEach-Object { $urls += $_ }
  } else {
    url $manifest "64bit" | ForEach-Object { $urls += $_ }
    url $manifest "32bit" | ForEach-Object { $urls += $_ }
  }

  $urls | ForEach-Object {
    $url,$status,$msg = test_dl $_ $manifest.cookie
    if ($msg) { $errors += "$msg ($url)" }
    if ($status -eq "OK" -or $status -eq "OpeningData") { $ok += 1 } else { $failed += 1 }
  }

  Write-Host "[" -NoNewline
  Write-Host -f cyan -NoNewline $urls.length
  Write-Host "]" -NoNewline

  Write-Host "[" -NoNewline
  if ($ok -eq $urls.length) {
    Write-Host -f green -NoNewline $ok
  } elseif ($ok -eq 0) {
    Write-Host -f red -NoNewline $ok
  } else {
    Write-Host -f yellow -NoNewline $ok
  }
  Write-Host "]" -NoNewline

  Write-Host "[" -NoNewline
  if ($failed -eq 0) {
    Write-Host -f green -NoNewline $failed
  } else {
    Write-Host -f red -NoNewline $failed
  }
  Write-Host "] " -NoNewline
  Write-Host (strip_ext $name)

  $errors | ForEach-Object {
    Write-Host -f darkred "       > $_"
  }
}


set_https_protocols $original
