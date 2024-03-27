# Usage: scoop analytics
# Summary: Collects and sends Scoop usage analytics to a remote server
# Help: This is an internal command. It is used to collect and send usage analytics
# to a remote server, at an interval of 7 days. The following data is collected:
# - Randomly generated (one-time) anonymous ID
# - Machine info
#   - OS build number
#   - OS Architecture
#   - PowerShell Desktop version
#   - PowerShell Core version
#   - Scoop version
# - Apps installed from public buckets (private apps are filtered out)
#   - Name
#   - Version
#   - Last updated
#   - Source
#   - Architecture
#   - User or Global installation
#   - Installation status
# - Public buckets (private buckets are filtered out)
#   - Name
#   - Source
#   - Last updated
#   - Manifest count

. "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'

if ([String]::IsNullOrEmpty((get_config ANALYTICS_ID))) {
    set_config ANALYTICS_ID (New-Guid).Guid | Out-Null
}
$def_arch = Get-DefaultArchitecture
$known_sources = foreach ($item in (known_bucket_repos).PSObject.Properties) { $item.Value }

function Test-PublicSource($source) {
    # Known sources
    if ($source -in $known_sources) {
        return $true
    }
    # Local file paths, SSH remotes, and remotes with usernames
    if ($source -match '^/[A-Za-z]:/|^[A-Za-z]:/|^\./|^\.\./|file:/|ssh:/|@') {
        return $false
    }
    return $true
}


$stats = [ordered]@{}
$stats.id = get_config ANALYTICS_ID

$stats.machine = [ordered]@{
    Build   = [System.Environment]::OSVersion.Version.ToString()
    Arch    = $def_arch
    Desktop = (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine -Name 'PowerShellVersion').PowerShellVersion
    Core    = if (Get-Command pwsh -ErrorAction Ignore) {
                  (Get-Item (Get-Command pwsh).Source).VersionInfo.ProductVersionRaw.ToString()
              } else {
                  ""
              }
    Scoop   = if (Test-Path "$PSScriptRoot\..\.git") {
                  $branch = (Get-Content "$PSScriptRoot\..\.git\HEAD").Replace('ref: ', '')
                  "$(Get-Content (Join-Path "$PSScriptRoot\..\.git" $branch)) ($($branch.Split('/')[-1]))"
              } elseif (Test-Path "$PSScriptRoot\..\CHANGELOG.md") {
                  (Select-String '^## .*([\d]{4}-[\d]{2}-[\d]{2})' "$PSScriptRoot\..\CHANGELOG.md").Matches.Groups[1].Value
              } else {
                  ""
              }
}

$bucket_names = @()
$stats.buckets = @()
foreach ($item in list_buckets) {
    # Filter out private buckets
    if (Test-PublicSource $item.Source) {
        $stats.buckets += $item
        $bucket_names += $item.Name
    }
}

$stats.apps = @()
foreach ($item in @(& "$PSScriptRoot\scoop-list.ps1" 6>$null)) {
    # Filter out private apps
    if ($item.Source -notin $bucket_names) {
        continue
    }

    $info = $item.Info -Split ', '

    $newitem         = [ordered]@{}
    $newitem.Name    = $item.Name
    $newitem.Version = $item.Version
    $newitem.Source  = $item.Source
    $newitem.Updated = $item.Updated
    $newitem.Global  = 'Global install' -in $info
    $newitem.Arch    = if ('64bit' -in $info -and '64bit' -ne $def_arch) {
        '64bit'
    } elseif ('32bit' -in $info -and '32bit' -ne $def_arch) {
        '32bit'
    } elseif ('arm64' -in $info -and 'arm64' -ne $def_arch) {
        'arm64'
    } else {
        $def_arch
    }
    $newitem.Status  = if ('Held package' -in $info) {
        'Held'
    } elseif ('Install failed' -in $info) {
        'Failed'
    } else {
        'OK'
    }

    $stats.apps += $newitem
}

$payload = $stats | ConvertToPrettyJSON

try {
    Invoke-RestMethod -Method Post `
        -Uri 'https://analytics.scoop.sh/post' `
        -Body $payload `
        -ContentType "application/json"
    set_config ANALYTICS_TIMESTAMP ([System.DateTime]::Now.ToString('o')) | Out-Null
} catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
}

exit 0

