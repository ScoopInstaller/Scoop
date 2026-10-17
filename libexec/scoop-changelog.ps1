# Usage: scoop changelog <app> [options]
# Summary: Show the changelog of an app
# Help: Shows the changelog of an app.
# Uses the 'changelog' property of the manifest when available, otherwise the
# notes of the app's latest GitHub release (or its CHANGELOG.md) are shown.
#
# Options:
#   -o, --open    Open the changelog in the browser instead of printing it

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
. "$PSScriptRoot\..\lib\manifest.ps1" # 'Get-Manifest', 'changelog_url', 'github_repo'
. "$PSScriptRoot\..\lib\download.ps1" # 'download_json', 'Get-Encoding', 'Get-UserAgent'

$opt, $apps, $err = getopt $args 'o' 'open'
if ($err) { error "scoop changelog: $err"; exit 1 }
if (!$apps) { my_usage; exit 1 }

$app, $manifest, $bucket, $url = Get-Manifest $apps[0]

if (!$manifest) {
    abort "Could not find manifest for '$app'$(if ($bucket) { " from '$bucket' bucket" } elseif ($url) { " at '$url'" })."
}

$changelog = changelog_url $manifest

if (!$changelog) {
    abort "Could not find a changelog for '$(show_app $app $bucket)'."
}

if ($opt.o -or $opt.open) {
    if ($changelog -notmatch '^https?://') { abort "Cannot open '$changelog': not an HTTP(S) URL." }
    Start-Process $changelog
    exit 0
}

function download_text($url) {
    $wc = New-Object Net.Webclient
    $wc.Headers.Add('User-Agent', (Get-UserAgent))
    get_config PRIVATE_HOSTS | Where-Object { $_ -ne $null -and $url -match $_.match } | ForEach-Object {
        (ConvertFrom-StringData -StringData $_.Headers).GetEnumerator() | ForEach-Object {
            $wc.Headers[$_.Key] = $_.Value
        }
    }
    $data = $wc.DownloadData($url)
    (Get-Encoding($wc)).GetString($data)
}

$ansi = @{
    Gray = "$([char]27)[37m"; White = "$([char]27)[97m"; Green = "$([char]27)[92m"
    DarkGreen = "$([char]27)[32m"; Cyan = "$([char]27)[96m"; DarkCyan = "$([char]27)[36m"
    DarkYellow = "$([char]27)[33m"; DarkGray = "$([char]27)[90m"; Reset = "$([char]27)[0m"
}

function write_md_line($line, $color, $pattern) {
    $out = ''
    $pos = 0
    foreach ($m in [regex]::Matches($line, $pattern)) {
        if ($m.Index -gt $pos) { $out += "$($ansi[$color])$($line.Substring($pos, $m.Index - $pos))$($ansi.Reset)" }
        $t = $m.Value
        $out += switch -Regex ($t) {
            '^`'      { "$($ansi.Green)$($t.Trim('`'))$($ansi.Reset)" }
            '^\*\*'   { "$($ansi.White)$($t.Trim('*'))$($ansi.Reset)" }
            '^!\['    { $l = $t -replace '^!\[([^\]]*)\]\([^)]*\)$', '$1'; "$($ansi.DarkGray)$l$($ansi.Reset)" }
            '^\['     { $l = $t -replace '^\[([^\]]+)\]\(([^)]+)\)$', '$1 ($2)'; "$($ansi.Cyan)$l$($ansi.Reset)" }
            '^https?' { "$($ansi.Cyan)$t$($ansi.Reset)" }
            '^<'      { '' }
            default   { "$($ansi[$color])$($t.Trim('*'))$($ansi.Reset)" }
        }
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $line.Length) { $out += "$($ansi[$color])$($line.Substring($pos))$($ansi.Reset)" }
    $out
}

function write_markdown($text) {
    $inline = '(`[^`]+`)|(\*\*[^*]+\*\*)|(!\[[^\]]*\]\([^)]*\))|(\[[^\]]+\]\([^)]+\))|(https?://[^\s)>]+)|(<[^>]+>)|(\*[^*\s][^*]*\*)'
    $inFence = $false
    $lines = foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^\s*```') { $inFence = !$inFence; continue }
        if ($inFence) { "$($ansi.DarkGreen)$line$($ansi.Reset)"; continue }
        $line = $line -replace '<(https?://[^>\s]+)>', '$1' # unwrap <url> autolinks
        if ($line -match '^\s*<!--' -or $line -match '^\s*</?\w+[^>]*>\s*$') { continue }
        if ($line -match '^\s*([-*_]\s*){3,}$') { "$($ansi.DarkGray)$([string][char]0x2500 * 48)$($ansi.Reset)"; continue }
        if ($line -match '^(#{1,6})\s+(.*)') {
            write_md_line $Matches[2] $(if ($Matches[1].Length -le 2) { 'Cyan' } else { 'DarkCyan' }) $inline
            continue
        }
        if ($line -match '^\s*>\s?(.*)') { write_md_line $Matches[1] 'DarkGray' $inline; continue }
        if ($line -match '^(\s*)([-*+])\s+(.*)') {
            "$($Matches[1])$($ansi.DarkYellow)$([char]0x2022)$($ansi.Reset) $(write_md_line $Matches[3] 'Gray' $inline)"
            continue
        }
        if ($line -match '^(\s*\d+\.)(\s+)(.*)') {
            "$($ansi.DarkYellow)$($Matches[1])$($ansi.Reset)$($Matches[2])$(write_md_line $Matches[3] 'Gray' $inline)"
            continue
        }
        if ($line -match '^ {4}') { "$($ansi.DarkGreen)$line$($ansi.Reset)"; continue }
        write_md_line $line 'Gray' $inline
    }
    $lines -join "`r`n"
}

# an explicit 'changelog' URL is authoritative: release notes are fetched only
# when it points at a GitHub repository root or its releases page (keeping a
# selected tag); otherwise the repository is derived from manifest fields
# ('checkver', 'homepage')
$repo = $null
$tag = $null
if ($manifest.changelog) {
    if ($changelog -match '(?:api\.github\.com/repos|(?<!api\.)github\.com)/(?<o>[\w.-]+)/(?<r>[\w.-]+?)(\.git)?/releases/tag/(?<t>[^/?#]+)') {
        $repo = "$($Matches.o)/$($Matches.r -replace '\.git$', '')"
        $tag = $Matches.t
    } elseif ($changelog -match '(?:api\.github\.com/repos|(?<!api\.)github\.com)/(?<o>[\w.-]+)/(?<r>[\w.-]+?)(\.git)?(/releases?([/?#].*)?)?/?$') {
        $repo = "$($Matches.o)/$($Matches.r -replace '\.git$', '')"
    }
} else {
    $repo = github_repo $manifest
}

$content = $null
$release = $null

if ($changelog -match '^https?://github\.com/(?<o>[\w.-]+)/(?<r>[\w.-]+)/blob/(?<b>[^/]+)/(?<f>.+?)/?$') {
    # 'changelog' points to a file in a GitHub repository
    $raw = "https://raw.githubusercontent.com/$($Matches.o)/$($Matches.r)/$($Matches.b)/$($Matches.f)"
    try {
        $content = download_text $raw
    } catch {
        warn "Could not fetch '$raw' ($($_.Exception.Message))."
    }
} elseif ($changelog -match '(raw\.githubusercontent\.com|\.(md|markdown|txt|rst|log))([?#].*)?$') {
    # 'changelog' points to a raw text file
    try {
        $content = download_text $changelog
    } catch {
        warn "Could not fetch '$changelog' ($($_.Exception.Message))."
    }
} elseif ($repo) {
    # GitHub repository -> notes of the selected (or latest) release, else CHANGELOG.md
    try {
        $release = download_json "https://api.github.com/repos/$repo/releases/$(if ($tag) { "tags/$tag" } else { 'latest' })"
        $content = $release.body
    } catch {
        $release_error = $_.Exception.Message
    }
    if (!$content) {
        try { $content = download_text "https://raw.githubusercontent.com/$repo/HEAD/CHANGELOG.md" } catch { }
        $rateLimited = try { github_ratelimit_reached } catch { $false }
        if (!$content -and $release_error -and !$rateLimited) {
            warn "Could not fetch the release notes of '$(show_app $app $bucket)' ($release_error)."
        }
    }
}

if ($content) {
    if ($release -and $release.body) {
        Write-Output "$(show_app $app $bucket) $(coalesce $release.name $release.tag_name)"
        Write-Output ''
    }
    # render with colors only for a terminal that supports ANSI escapes;
    # the body always goes to the success stream (pipeline-safe)
    $supportsVT = try { [bool]$Host.UI.SupportsVirtualTerminal } catch { $false }
    if ([Console]::IsOutputRedirected -or !$supportsVT -or $env:NO_COLOR) {
        Write-Output $content
    } else {
        Write-Output (write_markdown $content)
    }
    Write-Output ''
    info "Full changelog: $changelog"
} else {
    Write-Output "The changelog of '$(show_app $app $bucket)' is available at:"
    Write-Output $changelog
    info "Run 'scoop changelog $app -o' to open it in your browser."
}

exit 0
