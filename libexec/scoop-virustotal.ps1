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
. "$PSScriptRoot\..\lib\virustotal.ps1"
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest'
. "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'

$opt, $apps, $err = getopt $args 'asnup' @('all', 'scan', 'no-depends', 'no-update-scoop', 'passthru')
if ($err) { "scoop virustotal: $err"; exit 1 }
$all = $apps -eq '*' -or $opt.a -or $opt.all
if (!$apps -and !$all) { my_usage; exit 1 }
$architecture = Get-DefaultArchitecture

if (is_scoop_outdated) {
    if ($opt.u -or $opt.'no-update-scoop') {
        warn 'Scoop is out of date.'
    } else {
        & "$PSScriptRoot\scoop-update.ps1"
    }
}

if ($all) {
    $apps = (installed_apps $false) + (installed_apps $true)
}

if (!$opt.n -and !$opt.'no-depends') {
    $apps = $apps | Get-Dependency -Architecture $architecture | Select-Object -Unique
}

$api_key = Get-VirusTotalApiKey
$scan = $opt.s -or $opt.scan

$reports = $apps | ForEach-Object {
    $app = $_
    $null, $manifest, $bucket, $null = Get-Manifest $app
    if (!$manifest) {
        $exit_code = $exit_code -bor $_ERR_NO_INFO
        warn "$app`: manifest not found"
        return
    }

    $report = virustotal_check_app $app $manifest $architecture $api_key $scan
    if ($report) {
        $report
    }
}
if ($opt.p -or $opt.'passthru') {
    $reports
}

exit $exit_code
