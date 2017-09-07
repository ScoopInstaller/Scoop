# list manifests which do not specify a checkver regex
param(
    [String]$app,
    [String]$dir,
    [Int]$timeout = 5
)

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

$search = "*"
if($app) { $search = $app }

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\install.ps1"

if(!$dir) { $dir = "$psscriptroot\..\bucket" }
$dir = resolve-path $dir

# get apps to check
$queue = @()
gci $dir "$search.json" | % {
    $manifest = parse_json "$dir\$_"
    $queue += ,@($_, $manifest)
}

$original = use_any_https_protocol

write-host "[" -nonewline
write-host -f cyan "U" -nonewline
write-host "]RLs"
write-host " | [" -nonewline
write-host -f green "O" -nonewline
write-host "]kay"
write-host " |  | [" -nonewline
write-host -f red "F" -nonewline
write-host "]ailed"
write-host " |  |  |"

function test_dl($url, $cookies) {
    $wreq = [net.webrequest]::create($url)
    $wreq.timeout = $timeout * 1000
    if($wreq -is [net.httpwebrequest]) {
        $wreq.useragent = 'Scoop/1.0'
        $wreq.referer = strip_filename $url
        if($cookies) {
            $wreq.headers.add('Cookie', (cookie_header $cookies))
        }
    }
    $wres = $null
    try {
        $wres = $wreq.getresponse()
        return $url, $wres.statuscode, $null
    } catch {
        $e = $_.exception
        if($e.innerexception) { $e = $e.innerexception }
        return $url, "Error", $e.message
    } finally {
        if($wres -ne $null -and $wres -isnot [net.ftpwebresponse]) {
            $wres.close()
        }
    }
}

$queue | % {
    $name, $manifest = $_
    $urls = @()
    $ok = 0
    $failed = 0
    $errors = @()

    if($manifest.url) {
        $manifest.url | % { $urls += $_ }
    } else {
        url $manifest "64bit" | % { $urls += $_ }
        url $manifest "32bit" | % { $urls += $_ }
    }

    $urls | % {
        $url, $status, $msg = test_dl $_ $manifest.cookie
        if($msg) { $errors += "$msg ($url)" }
        if($status -eq "OK" -or $status -eq "OpeningData") { $ok += 1 } else { $failed += 1 }
    }

    write-host "[" -nonewline
    write-host -f cyan -nonewline $urls.length
    write-host "]" -nonewline

    write-host "[" -nonewline
    if($ok -eq $urls.length) {
        write-host -f green -nonewline $ok
    } elseif($ok -eq 0) {
        write-host -f red -nonewline $ok
    } else {
        write-host -f yellow -nonewline $ok
    }
    write-host "]" -nonewline

    write-host "[" -nonewline
    if($failed -eq 0) {
        write-host -f green -nonewline $failed
    } else {
        write-host -f red -nonewline $failed
    }
    write-host "] " -nonewline
    write-host (strip_ext $name)

    $errors | % {
        write-host -f darkred "       > $_"
    }
}


set_https_protocols $original
