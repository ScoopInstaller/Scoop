# checks websites for newer versions using an (optional) regular expression defined in the manifest
# use $dir to specify a manifest directory to check from, otherwise ./bucket is used
param(
    [String]$app,
    [String]$dir,
    [Switch]$update = $false,
    [Switch]$forceUpdate = $false
)

if (!$app -and $update) {
    # While developing the feature we only allow specific updates
    Write-Host "[ERROR] AUTOUPDATE CAN ONLY BE USED WITH A APP SPECIFIED" -f DarkRed
    exit
}

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\autoupdate.ps1"
. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\install.ps1" # needed for hash generation

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

$search = "*"
if($app) { $search = $app }

# get apps to check
$queue = @()
gci $dir "$search.json" | % {
    $json = parse_json "$dir\$_"
    if($json.checkver) {
        $queue += ,@($_, $json)
    }
}

# clear any existing events
get-event | % {
    remove-event $_.sourceidentifier
}

$original = use_any_https_protocol

# start all downloads
$queue | % {
    $wc = new-object net.webclient
    $wc.Headers.Add("user-agent", "Scoop/1.0 (+http://scoop.sh/) (Windows NT 6.1; WOW64)")
    register-objectevent $wc downloadstringcompleted -ea stop | out-null

    $name, $json = $_

    $githubRegex = "\/releases\/tag\/(?:v)?([\d.]+)"
    if ($json.checkver -is [String]) {
        if ($json.checkver -eq "github") {
            if (!$json.homepage.StartsWith("https://github.com/")) {
                write-host "ERROR: $name checkver expects the homepage to be a github repository" -f DarkYellow
            }

            $url = $json.homepage + "/releases/latest"
            $regex = $githubRegex
        } else {
            $url = $json.homepage
            $regex = $json.checkver
        }
    } else {
        if ($json.checkver.github) {
            $url = $json.checkver.github + "/releases/latest"
            $regex = $githubRegex
        } else {
            $url = $json.checkver.url
            if(!$url) { $url = $json.homepage }

            $regex = $json.checkver.re
        }
    }

    $state = new-object psobject @{
        app = (strip_ext $name);
        url = $url;
        regex = $regex;
        json = $json;
    }

    $wc.downloadstringasync($url, $state)
}

# wait for all to complete
$in_progress = $queue.length
while($in_progress -gt 0) {
    $ev = wait-event
    remove-event $ev.sourceidentifier
    $in_progress--

    $state = $ev.sourceeventargs.userstate
    $app = $state.app
    $json = $state.json
    $url = $state.url
    $expected_ver = $json.version
    $regexp = $state.regex

    $err = $ev.sourceeventargs.error
    $page = $ev.sourceeventargs.result

    write-host "$app`: " -nonewline

    if($err) {
        write-host -f darkred $err.message
        write-host -f darkred "URL $url is not valid"
    } else {
        if($page -match $regexp) {
            $ver = $matches[1]
            if(!$ver) {
                $ver = $matches['version']
            }
            if($ver -eq $expected_ver) {
                write-host "$ver" -f darkgreen

                if ($forceUpdate -and $json.autoupdate) {
                    Write-Host "Forcing autoupdate!" -f DarkMagenta
                    autoupdate $app $dir $json $ver $matches
                }
            } else {
                write-host "$ver" -f darkred -nonewline
                write-host " (scoop version is $expected_ver)" -NoNewline

                if ($json.autoupdate) {
                    Write-Host " autoupdate available" -f Cyan
                } else {
                    Write-Host ""
                }

                if($update -and $json.autoupdate) {
                    autoupdate $app $dir $json $ver $matches
                }
            }

        } else {
            write-host "couldn't match '$regexp' in $url" -f darkred
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
