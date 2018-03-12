# Usage: scoop virustotal <app> [options]
# Summary: Look for app's hash on virustotal.com
# Help: Look for app's hash (MD5, SHA1 or SHA256) on virustotal.com
#
# The download's hash is also a key to access VirusTotal's scan results.
# This allows to check the safety of the files without even downloading
# them in many cases.  If the hash is unknown to VirusTotal, the
# download link is printed to submit it to VirusTotal.
#
# Exit codes:
# 0 -> success
# 1 -> problem parsing arguments
# 2 -> at least one package was marked unsafe by VirusTotal
# 4 -> at least one exception was raised while looking for info
# 8 -> at least one package couldn't be queried because its hash type
#      isn't supported by VirusTotal, the manifest couldn't be found
#      or didn't contain a hash
# Note: the exit codes (2, 4 & 8) may be combined, e.g. 6 -> exit codes
#       2 & 4 combined
#
# Options:
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it
#   -s, --scan For packages where VirusTotal has no information, send download URL
#              for analysis (and future retrieval)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\config.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'a:s' @('arch=', 'scan')
if($err) { "scoop virustotal: $err"; exit 1 }
$architecture = ensure_architecture ($opt.a + $opt.arch)

$_ERR_UNSAFE = 2
$_ERR_EXCEPTION = 4
$_ERR_NO_INFO = 8

$exit_code = 0

Function Navigate-ToHash($hash, $app) {
    $hash = $hash.ToLower()
    $url = "https://www.virustotal.com/ui/files/$hash"
    $api_key = get_config("virustotal_api_key")
    if ($api_key) {
        $url += '?apikey=' + $api_key
    }
    $result = (new-object net.webclient).downloadstring($url)
    $stats = json_path $result '$.data.attributes.last_analysis_stats'
    $malicious = json_path $stats '$.malicious'
    $suspicious = json_path $stats '$.suspicious'
    $undetected = json_path $stats '$.undetected'
    $unsafe = [int]$malicious + [int]$suspicious
    $see_url = "see https://www.virustotal.com/#/file/$hash/detection"
    switch ($unsafe) {
        0 {$fg = "DarkGreen"}
        1 {$fg = "DarkYellow"}
        2 {$fg = "Yellow"}
        default {$fg = "Red"}
    }
    write-host -f $fg "$app`: $unsafe/$undetected, $see_url"
    if($unsafe -gt 0) {
        return $_ERR_UNSAFE
    }
    return 0
}

Function Start-VirusTotal ($h, $app) {
    if ($h -match "(?<algo>[^:]+):(?<hash>.*)") {
        $hash = $matches["hash"]
        if ($matches["algo"] -match "(md5|sha1|sha256)") {
            return Navigate-ToHash $hash $app
        }
        else {
            warn("$app`: Unsupported hash $($matches['algo']). VirusTotal needs md5, sha1 or sha256.")
            return $_ERR_NO_INFO
        }
    }
    else {
        return Navigate-ToHash $h $app
    }
}

Function Get-RedirectedUrl {
    # Follow up to one level of HTTP redirection
    #
    # Copied from http://www.powershellmagazine.com/2013/01/29/pstip-retrieve-a-redirected-url/
    # Adapted according to Roy's response (January 23, 2014 at 11:59 am)
    # Adapted to always return an URL
    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )
    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
    if ($response.StatusCode -eq "Found") {
        $redir = $response.GetResponseHeader("Location")
    }
    else {
        $redir = $URL
    }
    $response.Close()
    return $redir
}

Function SubmitMaybe-ToVirusTotal ($url, $app, $do_scan) {
    if ($do_scan) {
        try {
            # Follow redirections (for e.g. sourceforge URLs) because
            # VirusTotal analyzes only "direct" download links
            $url = $url.Split("#").GetValue(0)
            $new_redir = $url
            do {
                $orig_redir = $new_redir
                $new_redir = Get-RedirectedUrl $orig_redir
            } while ($orig_redir -ne $new_redir)
            $uri = "https://www.virustotal.com/ui/urls?url=$new_redir"
            $api_key = get_config("virustotal_api_key")
            if ($api_key) {
                $url += '&apikey=' + $api_key
            }
            Invoke-RestMethod -Method POST -Uri $uri | Out-Null
            $submitted = $True
        } catch [Exception] {
            warn("$app`: VirusTotal submission failed`: $($_.Exception.Message)")
            $submitted = $False
            return
        }
    }
    else {
        $submitted = $False
    }
    if ($submitted) {
        warn("$app`: not found`: submitted $url")
    }
    else {
        warn("$app`: not found`: manually submit $url")
    }
}

if(!$apps) {
    my_usage; exit 1
}

if(is_scoop_outdated) {
    scoop update
}

$apps_param = $apps

if($apps_param -eq '*') {
    $apps = applist (installed_apps $false) $false
} else {
    $apps = ensure_all_installed $apps_param
}

$requests = 0

$apps | ForEach-Object {
    ($app, $global) = $_
    $manifest, $bucket = find_manifest $app
    if(!$manifest) {
        $exit_code = $exit_code -bor $_ERR_NO_INFO
        warn("$app`: manifest not found")
        return
    }

    $hash = hash $manifest $architecture
    if (!$hash) {
        $exit_code = $exit_code -bor $_ERR_NO_INFO
        warn("$app`: hash not found in manifest")
        return
    }

    $url = url $manifest $architecture

    # Hacky way to see if $hash is an array (i.e. there was a list of
    # hashes in the manifest) or a string (i.e. there was 1! hash in
    # the manifest).
    if ($hash[0].Length -eq 1) {
        # Wrap download URL in array to traverse it in lockstep with
        # the loop over the hash.
        $url = @($url)
    }

    $hash | ForEach-Object { $i = 0 } {
        $requests += 1
        if ($requests -eq 5) {
            info("Sleeping 60+ seconds between requests due to VirusTotal's 4/min limit")
        }
        if ($requests -gt 4) {
            Start-Sleep -s (50 + ($requests * 2))
        }
        try {
            $exit_code = $exit_code -bor (Start-VirusTotal $_ $app)
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Message -like "*(404)*") {
                SubmitMaybe-ToVirusTotal $url[$i] $app ($opt.scan -or $opt.s)
            }
            else {
                if ($_.Exception.Message -match "\(204|429\)") {
                    abort "$app`: VirusTotal request failed`: $($_.Exception.Message)" $exit_code
                }
                warn("$app`: VirusTotal request failed`: $($_.Exception.Message)")
            }
        }
        $i = $i + 1
    }
}

exit $exit_code
