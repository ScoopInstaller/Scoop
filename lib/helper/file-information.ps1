### Remote file information

function Get-RemoteFileSize ($Uri) {
    $response = Invoke-WebRequest -Uri $Uri -Method HEAD -UseBasicParsing
    if (!$response.Headers.StatusCode) {
        $response.Headers.'Content-Length' | ForEach-Object { [int]$_ }
    }
}
