# Usage: scoop virustotal [* | app1 app2 ...] [options]
# Summary: Look for app's hash or url on virustotal.com
# Help: Look for app's hash or url on virustotal.com
#
# Use a single '*' or the '-a/--all' switch to check all installed apps.
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
#   -a, --all                 Check for all installed apps
#   -s, --scan                For packages where VirusTotal has no information, send download URL
#                             for analysis (and future retrieval). This requires you to configure
#                             your virustotal_api_key.
#   -n, --no-depends          By default, all dependencies are checked too. This flag avoids it.
#   -u, --no-update-scoop     Don't update Scoop before checking if it's outdated
#   -p, --passthru            Return reports as objects

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest'
. "$PSScriptRoot\..\lib\json.ps1" # 'json_path'
. "$PSScriptRoot\..\lib\download.ps1" # 'hash_for_url'
. "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'

$opt, $apps, $err = getopt $args 'asnup' @('all', 'scan', 'no-depends', 'no-update-scoop', 'passthru')
if ($err) { "scoop virustotal: $err"; exit 1 }
if (!$apps -and -$all) { my_usage; exit 1 }
$architecture = Format-ArchitectureString

if (is_scoop_outdated) {
    if ($opt.u -or $opt.'no-update-scoop') {
        warn 'Scoop is out of date.'
    } else {
        & "$PSScriptRoot\scoop-update.ps1"
    }
}

$apps_param = $apps

if ($apps_param -eq '*' -or $opt.a -or $opt.all) {
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
$api_key = get_config VIRUSTOTAL_API_KEY
if (!$api_key) {
    abort ("VirusTotal API key is not configured`n" +
        "  You could get one from https://www.virustotal.com/gui/my-apikey and set with`n" +
        "  scoop config virustotal_api_key <API key>") $_ERR_NO_API_KEY
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

Function Get-VirusTotalResultByHash ($hash, $url, $app) {
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
    [int]$fileSize = json_path $result '$.data.attributes.size'
    $report_hash = json_path $result '$.data.attributes.sha256'
    $report_url = "https://www.virustotal.com/gui/file/$report_hash"
    if ($total -eq 0) {
        info "$app`: Analysis in progress."
        [PSCustomObject] @{
            'App.Name'        = $app
            'App.Url'         = $url
            'App.Hash'        = $hash
            'App.HashType'    = $null
            'App.Size'        = filesize $fileSize
            'FileReport.Url'  = $report_url
            'FileReport.Hash' = $report_hash
            'UrlReport.Url'   = $null
        }
    } else {
        $vendorResults = (ConvertFrom-Json((json_path $result '$.data.attributes.last_analysis_results'))).PSObject.Properties.Value
        switch ($unsafe) {
            0 {
                success "$app`: $unsafe/$total, see $report_url"
            }
            1 {
                warn "$app`: $unsafe/$total, see $report_url"
            }
            2 {
                warn "$app`: $unsafe/$total, see $report_url"
            }
            Default {
                warn "$([char]0x1b)[31m$app`: $unsafe/$total, see $report_url$([char]0x1b)[0m"
            }
        }
        $maliciousResults = $vendorResults |
            Where-Object -Property category -EQ 'malicious' |
            Select-Object -ExpandProperty engine_name
        $suspiciousResults = $vendorResults |
            Where-Object -Property category -EQ 'suspicious' |
            Select-Object -ExpandProperty engine_name
        [PSCustomObject] @{
            'App.Name'              = $app
            'App.Url'               = $url
            'App.Hash'              = $hash
            'App.HashType'          = $null
            'App.Size'              = filesize $fileSize
            'FileReport.Url'        = $report_url
            'FileReport.Hash'       = $report_hash
            'FileReport.Malicious'  = if ($maliciousResults) { $maliciousResults } else { 0 }
            'FileReport.Suspicious' = if ($suspiciousResults) { $suspiciousResults } else { 0 }
            'FileReport.Timeout'    = $timeout
            'FileReport.Undetected' = $undetected
            'UrlReport.Url'         = $null
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
    $last_analysis_date = json_path $result '$.data.attributes.last_analysis_date' 6>$null
    $url_report_url = "https://www.virustotal.com/gui/url/$id"
    info "$app`: Url report found."
    if (!$hash) {
        if (!$last_analysis_date) {
            info "$app`: Analysis in progress."
        } else {
            info "$app`: Related file report not found."
            warn "$app`: Manual file upload is required (instead of url submission)."
        }
        [PSCustomObject] @{
            'App.Name'       = $app
            'App.Url'        = $url
            'App.Hash'       = $null
            'App.HashType'   = $null
            'FileReport.Url' = $null
            'UrlReport.Url'  = $url_report_url
            'UrlReport.Hash' = $null
        }
    } else {
        info "$app`: Related file report found."
        [PSCustomObject] @{
            'App.Name'       = $app
            'App.Url'        = $url
            'App.Hash'       = $null
            'App.HashType'   = $null
            'FileReport.Url' = $null
            'UrlReport.Url'  = $url_report_url
            'UrlReport.Hash' = $hash
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
        warn "$app`: not found`: you can manually submit $url"
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
            if ($fileSize -gt 80000000) {
                info "$app`: Remote file size: $(filesize $fileSize). Large files might require manual file upload instead of url submission."
            }
            info "$app`: Analysis in progress."
            [PSCustomObject] @{
                'App.Name'       = $app
                'App.Url'        = $url
                'App.Size'       = filesize $fileSize
                'FileReport.Url' = $null
                'UrlReport.Url'  = $url_report_url
            }
            return
        }

        # EAFP: submission failed -> sleep, then retry
        if (!$retrying) {
            if (!$explained_rate_limit_sleeping) {
                $explained_rate_limit_sleeping = $True
                info "Sleeping 60+ seconds between requests due to VirusTotal's 4/min limit"
            }
            Start-Sleep -s (60 + $requests)
            Submit-ToVirusTotal $url $app $do_scan $True
        } else {
            warn "$app`: VirusTotal submission of $url failed`:`n" +
            "`tAPI returned $($result.StatusCode) after retrying"
        }
    } catch [Exception] {
        warn "$app`: VirusTotal submission failed`: $($_.Exception.Message)"
        return
    }
}

$reports = $apps | ForEach-Object {
    $app = $_
    $null, $manifest, $bucket, $null = Get-Manifest $app
    if (!$manifest) {
        $exit_code = $exit_code -bor $_ERR_NO_INFO
        warn "$app`: manifest not found"
        return
    }

    [int]$index = 0
    $urls = script:url $manifest $architecture
    $urls | ForEach-Object {
        $url = $_
        $index++
        if ($urls.GetType().IsArray) {
            info "$app`: url $index"
        }
        $hash = hash_for_url $manifest $url $architecture

        try {
            $isHashUnsupported = $false
            if ($hash -match '(?<algo>[^:]+):(?<hash>.*)') {
                $algo = $matches.algo
                $hash = $matches.hash
                if ($matches.algo -inotin 'md5', 'sha1', 'sha256') {
                    $hash = $null
                    $isHashUnsupported = $true
                    warn "$app`: Unsupported hash $($matches.algo). Will search by url instead."
                }
            } elseif ($hash) {
                $algo = 'sha256'
            }
            if ($hash) {
                $file_report = Get-VirusTotalResultByHash $hash $url $app
                $file_report.'App.HashType' = $algo
                $file_report
                return
            } elseif (!$isHashUnsupported) {
                warn "$app`: Hash not found. Will search by url instead."
            }
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Response.StatusCode -eq 404) {
                $file_report_not_found = $true
                warn "$app`: File report not found. Will search by url instead."
            } else {
                if ($_.Exception.Response.StatusCode -in 204, 429) {
                    abort "$app`: VirusTotal request failed`: $($_.Exception.Message)" $exit_code
                }
                warn "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                return
            }
        }

        try {
            $url_report = Get-VirusTotalResultByUrl $url $app
            $url_report.'App.Hash' = $hash
            $url_report.'App.HashType' = $algo
            if ($url_report.'UrlReport.Hash' -and ($file_report_not_found -eq $true) -and $hash) {
                if ($algo -eq 'sha256') {
                    if ($url_report.'UrlReport.Hash' -eq $hash) {
                        warn "$app`: Manual file upload is required (instead of url submission) for $url"
                    } else {
                        error "$app`: Hash not matched for $url"
                    }
                } else {
                    error "$app`: Hash not matched or manual file upload is required (instead of url submission) for $url"
                }
                $url_report
                return
            }
            if (!$url_report.'UrlReport.Hash') {
                $url_report
                return
            }
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Response.StatusCode -eq 404) {
                warn "$app`: Url report not found. Will submit $url"
                Submit-ToVirusTotal $url $app ($opt.scan -or $opt.s)
                return
            } else {
                if ($_.Exception.Response.StatusCode -in 204, 429) {
                    abort "$app`: VirusTotal request failed`: $($_.Exception.Message)" $exit_code
                }
                warn "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                return
            }
        }

        try {
            $file_report = Get-VirusTotalResultByHash $url_report.'UrlReport.Hash' $url $app
            $file_report.'App.Hash' = $hash
            $file_report.'App.HashType' = $algo
            $file_report.'UrlReport.Url' = $url_report.'UrlReport.Url'
            $file_report
            warn "$app`: Unable to check hash match for $url"
        } catch [Exception] {
            $exit_code = $exit_code -bor $_ERR_EXCEPTION
            if ($_.Exception.Response.StatusCode -eq 404) {
                warn "$app`: File report not found for unknown reason. Manual file upload is required (instead of url submission)."
                $url_report
            } else {
                if ($_.Exception.Response.StatusCode -in 204, 429) {
                    abort "$app`: VirusTotal request failed`: $($_.Exception.Message)" $exit_code
                }
                warn "$app`: VirusTotal request failed`: $($_.Exception.Message)"
                return
            }
        }
    }
}
if ($opt.p -or $opt.'passthru') {
    $reports
}

exit $exit_code
