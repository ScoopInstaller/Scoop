# Usage: scoop virustotal [* | app1 app2 ...] [options]
# Summary: Look for app's hash or url on virustotal.com
# Help: Look for app's hash or url on virustotal.com
#
# Use a single '*' for app to check all installed apps.
#
# To use this command, you have to sign up to VirusTotal's community,
# and get an API key. Then, tell scoop about your API key with:
#
#   scoop config virustotal_api_key <your API key: 64 lower case hex digits>
#
# Exit codes:
#  0 -> success
#  1 -> problem parsing arguments
#  2 -> at least one package was marked unsafe by VirusTotal
#  4 -> at least one exception was raised while looking for info
#  8 -> at least one package couldn't be queried because the manifest couldn't be found
# 16 -> VirusTotal API key is not configured
# Note: the exit codes (2, 4 & 8) may be combined, e.g. 6 -> exit codes
#       2 & 4 combined
#
# Options:
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it
#   -s, --scan                For packages where VirusTotal has no information, send download URL
#                             for analysis (and future retrieval). This requires you to configure
#                             your virustotal_api_key.
#   -n, --no-depends          By default, all dependencies are checked too. This flag avoids it.
#   -u, --no-update-scoop     Don't update Scoop before checking if it's outdated

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest'
. "$PSScriptRoot\..\lib\json.ps1" # 'json_path'
. "$PSScriptRoot\..\lib\install.ps1" # 'hash_for_url'
. "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'

$opt, $apps, $err = getopt $args 'a:snu' @('arch=', 'scan', 'no-depends', 'no-update-scoop')
if ($err) { "scoop virustotal: $err"; exit 1 }
if (!$apps) { my_usage; exit 1 }
$architecture = ensure_architecture ($opt.a + $opt.arch)

if (is_scoop_outdated) {
    if ($opt.u -or $opt.'no-update-scoop') {
        Write-Warning 'Scoop is out of date.'
    } else {
        scoop update
    }
}

$apps_param = $apps

if ($apps_param -eq '*') {
    $apps = installed_apps $false
    $apps += installed_apps $true
}

if (!$opt.n -and !$opt.'no-depends') {
    $apps = $apps | Get-Dependency -Architecture $architecture | Select-Object -Unique
}

$_ERR_UNSAFE = 2
$_ERR_EXCEPTION = 4
$_ERR_NO_INFO = 8
$_ERR_NO_API_KEY = 16

$exit_code = 0

# Global API key:
$api_key = get_config virustotal_api_key
if (!$api_key) {
    Write-Warning ("VirusTotal API key is not configured`n`n" +
        "`tscoop config virustotal_api_key <API key>")
    exit $_ERR_NO_API_KEY
}

# Global flag to explain only once about sleep between requests
$explained_rate_limit_sleeping = $False

# Requests counter to slow down requests submitted to VirusTotal as
# script execution progresses
$requests = 0

Function ConvertTo-VirusTotalUrlId ($url) {
    $url_id = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($url))
    $url_id = $url_id -replace '\+', '-'
    $url_id = $url_id -replace '/', '_'
    $url_id = $url_id -replace '=', ''
    $url_id
}

Function Get-RemoteFileSize ($url) {
    $response = Invoke-WebRequest -Uri $url -Method HEAD -UseBasicParsing
    $response.Headers.'Content-Length' | ForEach-Object {
        ([System.Convert]::ToDouble($_) / 1048576)
    }
}

Function Get-VirusTotalResultByHash ($hash, $app) {
    $hash = $hash.ToLower()
    $api_url = "https://www.virustotal.com/api/v3/files/$hash"
    $headers = @{}
    $headers.Add('Accept', 'application/json')
    $headers.Add('x-apikey', $api_key)
    $response = Invoke-WebRequest -Uri $api_url -Method GET -Headers $headers -UseBasicParsing
    $result = $response.Content
    $stats = json_path $result '$.data.attributes.last_analysis_stats'
    [int]$malicious = json_path $stats '$.malicious'
    [int]$suspicious = json_path $stats '$.suspicious'
    [int]$timeout = json_path $stats '$.timeout'
    [int]$undetected = json_path $stats '$.undetected'
    [int]$unsafe = $malicious + $suspicious
    [int]$total = $unsafe + $undetected
    $fileSize = ([System.Convert]::ToDouble((json_path $result '$.data.attributes.size')) / 1048576)
    $report_url = "https://www.virustotal.com/gui/file/$hash"
    if ($total -eq 0) {
        Write-Information "INFO   : $app`: Analysis in progress." -InformationAction 'Continue'
        [PSCustomObject] @{
            'App.Name'      = $app
            'App.Hash'      = $hash
            'App.Size (MB)' = $fileSize.ToString('0.00')
            FileReport      = $report_url
            UrlReport       = $null
        }
    } else {
        $vendorResults = (ConvertFrom-Json((json_path $result '$.data.attributes.last_analysis_results'))).PSObject.Properties.Value
        switch ($unsafe) {
            0 {
                Write-Information "$($PSStyle.Foreground.BrightGreen)INFO   : $app`: $unsafe/$total$($PSStyle.Reset)" -InformationAction 'Continue'
            }
            1 {
                Write-Warning "$app`: $unsafe/$total"
            }
            2 {
                Write-Warning "$app`: $unsafe/$total"
            }
            Default {
                Write-Warning "$app`: $($PSStyle.Formatting.Error)$unsafe$($PSStyle.Formatting.Warning)/$total"
            }
        }
        $maliciousResults = $vendorResults |
            Where-Object -Property category -EQ 'malicious' |
            Select-Object -ExpandProperty engine_name
        $suspiciousResults = $vendorResults |
            Where-Object -Property category -EQ 'suspicious' |
            Select-Object -ExpandProperty engine_name
        [PSCustomObject] @{
            'App.Name'      = $app
            'App.Hash'      = $hash
            'App.Size (MB)' = $fileSize.ToString('0.00')
            FileReport      = $report_url
            Malicious       = if ($maliciousResults) { $maliciousResults } else { 0 }
            Suspicious      = if ($suspiciousResults) { $suspiciousResults } else { 0 }
            Timeout         = $timeout
            Undetected      = $undetected
            UrlReport       = $null
        }
    }
    if ($unsafe -gt 0) {
        $Script:exit_code = $exit_code -bor $_ERR_UNSAFE
    }
}

Function Get-VirusTotalResultByUrl ($url, $app) {
    $id = ConvertTo-VirusTotalUrlId $url
    $api_url = "https://www.virustotal.com/api/v3/urls/$id"
    $headers = @{}
    $headers.Add('Accept', 'application/json')
    $headers.Add('x-apikey', $api_key)
    $response = Invoke-WebRequest -Uri $api_url -Method GET -Headers $headers -UseBasicParsing
    $result = $response.Content
    $id = json_path $result '$.data.id'
    $hash = json_path $result '$.data.attributes.last_http_response_content_sha256' 6>$null
    $url_report_url = "https://www.virustotal.com/gui/url/$id"
    Write-Information "INFO   : $app`: Url report found."
    if (!$hash) {
        Write-Information "INFO   : $app`: Related file report not found."
        Write-Warning "$app`: Manual file upload is required (instead of url submission)."
        [PSCustomObject] @{
            'App.Name' = $app
            'App.Hash' = $null
            FileReport = $null
            UrlReport  = $url_report_url
        }
    } else {
        Write-Information "INFO   : $app`: Related file report found."
        [PSCustomObject] @{
            'App.Name' = $app
            'App.Hash' = $hash
            FileReport = $null
            UrlReport  = $url_report_url
        }
    }
}

# Submit-ToVirusTotal
# - $url: where file to check can be downloaded
# - $app: Name of the application (used for reporting)
# - $do_scan: [boolean flag] whether to actually submit to VirusTotal
#             This is a parameter instead of conditionnally calling
#             the function to consolidate the warning message
# - $retrying: [boolean] Optional, for internal use to retry
#              submitting the file after a delay if the rate limit is
#              exceeded, without risking an infinite loop (as stack
#              overflow) if the submission keeps failing.
Function Submit-ToVirusTotal ($url, $app, $do_scan, $retrying = $False) {
    if (!$do_scan) {
        Write-Warning "$app`: not found`: you can manually submit $url"
        return
    }

    try {
        $requests += 1

        $encoded_url = [System.Web.HttpUtility]::UrlEncode($url)
        $api_url = 'https://www.virustotal.com/api/v3/urls'
        $content_type = 'application/x-www-form-urlencoded'
        $headers = @{}
        $headers.Add('Accept', 'application/json')
        $headers.Add('x-apikey', $api_key)
        $headers.Add('Content-Type', $content_type)
        $body = "url=$encoded_url"
        $result = Invoke-WebRequest -Uri $api_url -Method POST -Headers $headers -ContentType $content_type -Body $body -UseBasicParsing
        if ($result.StatusCode -eq 200) {
            $id = ((json_path $result '$.data.id') -split '-')[1]
            $url_report_url = "https://www.virustotal.com/gui/url/$id"
            $fileSize = Get-RemoteFileSize $url
            if ($fileSize -gt 70) {
                Write-Information "INFO   : $app`: Remote file size: $($fileSize.ToString('0.00 MB')). Large files might require manual file upload instead of url submission." -InformationAction 'Continue'
            }
            Write-Information "INFO   : $app`: Analysis in progress." -InformationAction 'Continue'
            [PSCustomObject] @{
                'App.Name'      = $app
                'App.Size (MB)' = $fileSize.ToString('0.00')
                FileReport      = $null
                UrlReport       = $url_report_url
            }
            return
        }

        # EAFP: submission failed -> sleep, then retry
        if (!$retrying) {
            if (!$explained_rate_limit_sleeping) {
                $explained_rate_limit_sleeping = $True
                Write-Information "INFO   : Sleeping 60+ seconds between requests due to VirusTotal's 4/min limit" -InformationAction 'Continue'
            }
            Start-Sleep -s (60 + $requests)
            Submit-ToVirusTotal $url $app $do_scan $True
        } else {
            Write-Warning "$app`: VirusTotal submission of $url failed`:`n" +
            "`tAPI returned $($result.StatusCode) after retrying"
        }
    } catch [Exception] {
        Write-Warning "$app`: VirusTotal submission failed`: $($_.Exception.Message)"
        return
    }
}

$reports = $apps | ForEach-Object {
    $app = $_
    $null, $manifest, $bucket, $null = Get-Manifest $app
    if (!$manifest) {
        $exit_code = $exit_code -bor $_ERR_NO_INFO
        Write-Warning "$app`: manifest not found"
        return
    }

    $urls = script:url $manifest $architecture
    $urls | ForEach-Object {
        $url = $_
        $hash = hash_for_url $manifest $url $architecture

        try {
            $isHashUnsupported = $false
            if ($hash -match '(?<algo>[^:]+):(?<hash>.*)') {
                $hash = $matches.hash
                if ($matches.algo -notmatch '(md5|sha1|sha256)') {
                    $hash = $null
                    $isHashUnsupported = $true
                    Write-Warning "$app`: Unsupported hash $($matches.algo). Will search by url instead."
                }
            }
            if ($hash) {
                $file_report = Get-VirusTotalResultByHash $hash $app
                $file_report
                return
            } elseif (!$isHashUnsupported) {
                Write-Warning "$app`: Hash not found. Will search by url instead."
            }
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Warning "$app`: File report not found. Will search by url instead."
            } else {
                if ($_.Exception.Response.StatusCode -in 204, 429) {
                    Write-Error "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                    exit $exit_code
                }
                Write-Warning "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                return
            }
        }

        try {
            $url_report = Get-VirusTotalResultByUrl $url $app
            $hash = $url_report.'App.Hash'
            if ($hash) {
                $file_report = Get-VirusTotalResultByHash $hash $app
                $file_report.'UrlReport' = $url_report.'UrlReport'
                $file_report
            } else {
                $url_report
            }
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Warning "$app`: Url report not found. Will submit $url"
                Submit-ToVirusTotal $url $app ($opt.scan -or $opt.s)
            } else {
                if ($_.Exception.Response.StatusCode -in 204, 429) {
                    Write-Error "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                    exit $exit_code
                }
                Write-Warning "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                return
            }
        }
    }
}
$reports

exit $exit_code
