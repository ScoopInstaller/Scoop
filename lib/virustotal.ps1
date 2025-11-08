. "$PSScriptRoot\json.ps1" # 'json_path'
. "$PSScriptRoot\..\lib\helper\hash.ps1" # 'hash_for_url'
. "$PSScriptRoot\..\lib\helper\file-information.ps1" # 'Get-RemoteFileSize'

# Error codes
$_ERR_UNSAFE = 2
$_ERR_EXCEPTION = 4
$_ERR_NO_INFO = 8
$_ERR_NO_API_KEY = 16

# Global state variables
$script:requests = 0
$script:explained_rate_limit_sleeping = $False
$exit_code = 0

function ConvertTo-VirusTotalUrlId ($url) {
    $url_id = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($url))
    $url_id = $url_id -replace '\+', '-'
    $url_id = $url_id -replace '/', '_'
    $url_id = $url_id -replace '=', ''
    $url_id
}

function Get-VirusTotalResultByHash ($hash, $url, $app, $api_key) {
    $hash = $hash.ToLower()
    $api_url = "https://www.virustotal.com/api/v3/files/$hash"
    $headers = @{
        'Accept'   = 'application/json'
        'x-apikey' = $api_key
    }
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
            0 { success "$app`: $unsafe/$total, see $report_url" }
            1 { warn "$app`: $unsafe/$total, see $report_url" }
            2 { warn "$app`: $unsafe/$total, see $report_url" }
            Default { warn "$([char]0x1b)[31m$app`: $unsafe/$total, see $report_url$([char]0x1b)[0m" }
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
            'FileReport.MaliciousResults'  = if ($maliciousResults) { $maliciousResults } else { @() }
            'FileReport.SuspiciousResults' = if ($suspiciousResults) { $suspiciousResults } else { @() }
            'FileReport.Malicious' = $malicious
            'FileReport.Suspicious' = $suspicious
            'FileReport.Timeout'    = $timeout
            'FileReport.Undetected' = $undetected
            'FileReport.Unsafe'     = $unsafe
            'FileReport.Total'       = $total
            'UrlReport.Url'         = $null
        }
    }
    if ($unsafe -gt 0) {
        $exit_code = $exit_code -bor $_ERR_UNSAFE
    }
}

function Get-VirusTotalResultByUrl ($url, $app, $api_key) {
    $id = ConvertTo-VirusTotalUrlId $url
    $api_url = "https://www.virustotal.com/api/v3/urls/$id"
    $headers = @{
        'Accept'   = 'application/json'
        'x-apikey' = $api_key
    }
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
# - $api_key: VirusTotal API key
# - $retrying: [boolean] Optional, for internal use to retry
#              submitting the file after a delay if the rate limit is
#              exceeded, without risking an infinite loop (as stack
#              overflow) if the submission keeps failing.
function Submit-ToVirusTotal ($url, $app, $do_scan, $api_key, $retrying = $False) {
    if (!$do_scan) {
        warn "$app`: not found`: you can manually submit $url"
        return
    }

    try {
        $script:requests += 1

        $encoded_url = [System.Web.HttpUtility]::UrlEncode($url)
        $api_url = 'https://www.virustotal.com/api/v3/urls'
        $content_type = 'application/x-www-form-urlencoded'
        $headers = @{
            'Accept'       = 'application/json'
            'x-apikey'     = $api_key
            'Content-Type' = $content_type
        }
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
                'App.Hash'       = $null
                'App.HashType'   = $null
                'FileReport.Url' = $null
                'UrlReport.Url'  = $url_report_url
                'UrlReport.Hash' = $null
            }
            return
        }

        # EAFP: submission failed -> sleep, then retry
        if (!$retrying) {
            if (!$script:explained_rate_limit_sleeping) {
                info 'VirusTotal API has rate limits. Waiting between requests...'
                $script:explained_rate_limit_sleeping = $True
            }
            Start-Sleep -s (60 + $script:requests)
            Submit-ToVirusTotal $url $app $do_scan $api_key $True
        } else {
            warn "$app`: VirusTotal submission of $url failed`:`n" +
            "`tAPI returned $($result.StatusCode) after retrying"
        }
    } catch [Exception] {
        warn "$app`: VirusTotal submission failed`: $($_.Exception.Message)"
        return
    }
}

function Get-VirusTotalApiKey {
    $api_key = get_config VIRUSTOTAL_API_KEY
    if (!$api_key) {
        abort ("VirusTotal API key is not configured`n" +
            "  You could get one from https://www.virustotal.com/gui/my-apikey and set with`n" +
            "  scoop config virustotal_api_key <API key>") $_ERR_NO_API_KEY
    }
    return $api_key
}

function Check-VirusTotalUrl($app, $url, $hash, $api_key, $scan) {
    $isHashUnsupported = $false
    $algo = $null

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

    try {
        if ($hash) {
            $file_report = Get-VirusTotalResultByHash $hash $url $app $api_key
            $file_report.'App.HashType' = $algo
            return $file_report
        } elseif (!$isHashUnsupported) {
            warn "$app`: Hash not found. Will search by url instead."
        }
    } catch [Exception] {
        $exit_code = $exit_code -bor $_ERR_EXCEPTION
        if ($_.Exception.Response.StatusCode -eq 404) {
            $file_report_not_found = $true
            warn "$app`: File report not found. Will search by url instead."
        } else {
            warn "$app`: VirusTotal file report query failed`: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                warn "`tAPI returned $($_.Exception.Response.StatusCode)"
            }
            return
        }
    }

    try {
        $url_report = Get-VirusTotalResultByUrl $url $app $api_key
        $url_report.'App.Hash' = $hash
        $url_report.'App.HashType' = $algo
        if ($url_report.'UrlReport.Hash' -and ($file_report_not_found -eq $true) -and $hash) {
            try {
                $file_report = Get-VirusTotalResultByHash $url_report.'UrlReport.Hash' $url $app $api_key
                if ($file_report.'FileReport.Hash' -ieq $matches['hash']) {
                    $file_report.'App.HashType' = $algo
                    $file_report.'UrlReport.Url' = $url_report.'UrlReport.Url'
                    return $file_report
                }
            } catch {
                warn "$app`: Unable to get file report for $($url_report.'UrlReport.Hash')"
            }
        }
        if (!$url_report.'UrlReport.Hash') {
            Submit-ToVirusTotal $url $app $scan $api_key
            return $url_report
        }
    } catch [Exception] {
        $exit_code = $exit_code -bor $_ERR_EXCEPTION
        if ($_.Exception.Response.StatusCode -eq 404) {
            Submit-ToVirusTotal $url $app $scan $api_key
            return
        } else {
            warn "$app`: VirusTotal URL report query failed`: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                warn "`tAPI returned $($_.Exception.Response.StatusCode)"
            }
            return
        }
    }

    try {
        $file_report = Get-VirusTotalResultByHash $url_report.'UrlReport.Hash' $url $app $api_key
        $file_report.'App.Hash' = $hash
        $file_report.'App.HashType' = $algo
        $file_report.'UrlReport.Url' = $url_report.'UrlReport.Url'
        $file_report
        warn "$app`: Unable to check hash match for $url"
    } catch [Exception] {
        $exit_code = $exit_code -bor $_ERR_EXCEPTION
        if ($_.Exception.Response.StatusCode -eq 404) {
            Submit-ToVirusTotal $url $app $scan $api_key
            $url_report
        } else {
            warn "$app`: VirusTotal file report query failed`: $($_.Exception.Message)"
            if ($_.Exception.Response) {
                warn "`tAPI returned $($_.Exception.Response.StatusCode)"
            }
            return
        }
    }
}

function virustotal_check_app($app, $manifest, $architecture, $api_key, $scan) {
    [int]$index = 0
    $urls = script:url $manifest $architecture
    $urls | ForEach-Object {
        $url = $_
        $index++
        if ($urls.GetType().IsArray) {
            info "$app`: url $index"
        }
        $hash = hash_for_url $manifest $url $architecture
        Check-VirusTotalUrl $app $url $hash $api_key $scan
    }
}

# return only the URLs that passed VirusTotal checks
function Test-UrlsWithVirusTotal($app, $urls, $manifest, $architecture) {
    $safe_urls = @()
    $api_key = Get-VirusTotalApiKey

    foreach ($url in $urls) {
        $hash = hash_for_url $manifest $url $architecture
        $reports = Check-VirusTotalUrl $app $url $hash $api_key $false

        $reports | ForEach-Object {
            $file_report = $_
            $url = $file_report.'App.Url'

            if ($file_report.'FileReport.Unsafe' -eq 0) {
                info "$app`: Safe URL: $url"
                $safe_urls += $url
            } else {
                warn "$app`: Unsafe URL: $url"
            }
        }
    }

    if ($safe_urls.Count -eq 0) {
        abort "VirusTotal check for $app failed. Aborting before download."
    }

    return $safe_urls
}
