# checks websites for newer versions using an (optional) regular expression defined in the manifest
# use $dir to specify a manifest directory to check from, otherwise ./bucket is used
param(
  [string]$app,
  [string]$dir,
  [switch]$update = $false,
  [switch]$forceUpdate = $false
)

if (!$app -and $update) {
  # While developing the feature we only allow specific updates
  Write-Host "[ERROR] AUTOUPDATE CAN ONLY BE USED WITH A APP SPECIFIED" -f DarkRed
  exit
}

."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\manifest.ps1"
."$psscriptroot\..\lib\config.ps1"
."$psscriptroot\..\lib\buckets.ps1"
."$psscriptroot\..\lib\autoupdate.ps1"
."$psscriptroot\..\lib\json.ps1"
."$psscriptroot\..\lib\versions.ps1"
."$psscriptroot\..\lib\install.ps1" # needed for hash generation
."$psscriptroot\..\lib\unix.ps1"

if (!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = Resolve-Path $dir

$search = "*"
if ($app) { $search = $app }

# get apps to check
$queue = @()
Get-ChildItem $dir "$search.json" | ForEach-Object {
  $json = parse_json "$dir\$_"
  if ($json.checkver) {
    $queue +=,@( $_,$json)
  }
}

# clear any existing events
Get-Event | ForEach-Object {
  Remove-Event $_.sourceidentifier
}

$original = use_any_https_protocol

# start all downloads
$queue | ForEach-Object {
  $wc = New-Object net.webclient
  $wc.headers.Add("user-agent","Scoop/1.0 (+http://scoop.sh/) (Windows NT 6.1; WOW64)")
  Register-ObjectEvent $wc downloadstringcompleted -ea stop | Out-Null

  $name,$json = $_

  $githubRegex = "\/releases\/tag\/(?:v)?([\d.]+)"

  $url = $json.homepage
  if ($json.checkver.url) {
    $url = $json.checkver.url
  }
  $regex = ""
  $jsonpath = ""
  $replace = ""

  if ($json.checkver -eq "github") {
    if (!$json.homepage.StartsWith("https://github.com/")) {
      Write-Host "ERROR: $name checkver expects the homepage to be a github repository" -f DarkYellow
    }
    $url = $json.homepage + "/releases/latest"
    $regex = $githubRegex
  }

  if ($json.checkver.github) {
    $url = $json.checkver.github + "/releases/latest"
    $regex = $githubRegex
  }

  if ($json.checkver.re) {
    $regex = $json.checkver.re
  }

  if ($json.checkver.jp) {
    $jsonpath = $json.checkver.jp
  }

  if ($json.checkver.Replace -and $json.checkver.Replace.GetType() -eq [System.String]) {
    $replace = $json.checkver.Replace
  }

  if (!$jsonpath -and !$regex) {
    $regex = $json.checkver
  }

  $reverse = $json.checkver.Reverse -and $json.checkver.Reverse -eq "true"

  $state = New-Object psobject @{
    app = (strip_ext $name);
    url = $url;
    regex = $regex;
    json = $json;
    jsonpath = $jsonpath;
    Reverse = $reverse;
    Replace = $replace;
  }

  $wc.headers.Add('Referer',(strip_filename $url))
  $wc.downloadstringasync($url,$state)
}

# wait for all to complete
$in_progress = $queue.length
while ($in_progress -gt 0) {
  $ev = Wait-Event
  Remove-Event $ev.sourceidentifier
  $in_progress --

  $state = $ev.sourceeventargs.userstate
  $app = $state.app
  $json = $state.json
  $url = $state.url
  $expected_ver = $json.version
  $regexp = $state.regex
  $jsonpath = $state.jsonpath
  $reverse = $state.Reverse
  $replace = $state.Replace
  $ver = ""

  $err = $ev.sourceeventargs.error
  $page = $ev.sourceeventargs.result

  Write-Host "$app`: " -NoNewline

  if ($err) {
    Write-Host -f darkred $err.message
    Write-Host -f darkred "URL $url is not valid"
    continue
  }

  if (!$regex -and $replace) {
    Write-Host -f darkred "'replace' requires 're'"
    continue
  }

  if ($jsonpath) {
    $ver = json_path $page $jsonpath
    if (!$ver) {
      $ver = json_path_legacy $page $jsonpath
    }
    if (!$ver) {
      Write-Host -f darkred "couldn't find '$jsonpath' in $url"
      continue
    }
  }

  if ($jsonpath -and $regexp) {
    $page = $ver
    $ver = ""
  }

  if ($regexp) {
    $regex = New-Object System.Text.RegularExpressions.Regex ($regexp)
    if ($reverse) {
      $match = $regex.matches($page) | Select-Object -Last 1
    } else {
      $match = $regex.matches($page) | Select-Object -First 1
    }

    if ($match -and $match.Success) {
      $matchesHashtable = @{}
      $regex.GetGroupNames() | ForEach-Object { $matchesHashtable.Add($_,$match.Groups[$_].Value) }
      $ver = $matchesHashtable['1']
      if ($replace) {
        $ver = $regex.Replace($match.Value,$replace)
      }
      if (!$ver) {
        $ver = $matchesHashtable['version']
      }
    } else {
      Write-Host -f darkred "couldn't match '$regexp' in $url"
      continue
    }
  }

  if (!$ver) {
    Write-Host -f darkred "couldn't find new version in $url"
    continue
  }

  if ($ver -eq $expected_ver -and $forceUpdate -eq $false) {
    # version hasn't changed (step over if forced update)
    Write-Host "$ver" -f darkgreen
    continue
  }

  Write-Host "$ver" -f darkred -NoNewline
  Write-Host " (scoop version is $expected_ver)" -NoNewline
  $update_available = (compare_versions $expected_ver $ver) -eq -1

  if ($json.autoupdate -and $update_available) {
    Write-Host " autoupdate available" -f Cyan
  } else {
    Write-Host ""
  }

  if ($forceUpdate) {
    # forcing an update implies updating, right?
    $update = $true
  }

  if ($update -and $json.autoupdate) {
    if ($forceUpdate) {
      Write-Host "Forcing autoupdate!" -f DarkMagenta
    }
    try {
      autoupdate $app $dir $json $ver $matchesHashtable
    } catch {
      error $_.exception.message
    }
  }
}

set_https_protocols $original

<#
write-host "checking $(strip_ext (fname $_))..." -nonewline
$expected_ver = $json.version

$url = $json.checkver.url
if(!$url) { $url = $json.homepage }

$regexp = $json.checkver.re
if(!$regexp) { $regexp = $json.checkver }

$page = $wc.downloadstring($url)

if($page -match $regexp) {
    $ver = $matches[1]
    if($ver -eq $expected_ver) {
        write-host "$ver" -f darkgreen
    } else {
        write-host "$ver" -f darkred -nonewline
        write-host " (scoop version is $expected_ver)"
    }

} else {
    write-host "couldn't match '$regexp' in $url" -f darkred
}
#>
