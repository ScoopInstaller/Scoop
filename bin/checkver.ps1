# checks websites for newer versions using an (optional) regular expression defined in the manifest
# use $dir to specify a manifest directory to check from, otherwise ./bucket is used
param($app, $dir)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\config.ps1"

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

# start all downloads
$queue | % {
    $wc = new-object net.webclient
    $wc.Headers.Add("user-agent", "Scoop/1.0 (+http://scoop.sh/)")
    register-objectevent $wc downloadstringcompleted -ea stop | out-null

    $name, $json = $_

    $url = $json.checkver.url
    if(!$url) { $url = $json.homepage }

    $state = new-object psobject @{
        app = (strip_ext $name);
        url = $url;
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

    $err = $ev.sourceeventargs.error
    $page = $ev.sourceeventargs.result

    $regexp = $json.checkver.re
    if(!$regexp) { $regexp = $json.checkver }

    $regexp = "(?s)$regexp"

    write-host "$app`: " -nonewline

    if($err) {
        write-host "ERROR: $err" -f darkyellow
    } else {
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
    }
}

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
