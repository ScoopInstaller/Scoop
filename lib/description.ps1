function find_description($url, $html, $redir = $false) {
    $meta = meta_tags $html

    # check <meta property="og:description">
    $og_description = meta_content $meta 'property' 'og:description'
    if($og_description) {
        return $og_description, '<meta property="og:description">'
    }

    # check <meta name="description">
    $description = meta_content $meta 'name' 'description'
    if($description) {
        return $description, '<meta name="description">'
    }

    # check <meta http-equiv="refresh"> redirect
    $refresh = meta_refresh $meta $url
    if($refresh -and !$redir) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $data = $wc.DownloadData($refresh)
        $html = (Get-Encoding($wc)).GetString($data)
        return find_description $refresh $html $true
    }

    # check text for 'x is ...'
    $text = html_text $html $meta
    $text_desc = find_is $text
    if($text_desc) {
        return $text_desc, 'text'
    }

    # first paragraph
    $first_para = first_para $html
    if($first_para) {
        return $first_para, 'first <p>'
    }

    return $null, $null
}

function clean_description($description) {
    if(!$description) { return $description }
    $description = $description -replace '\n', ' '
    $description = $description -replace '\s{2,}', ' '
    return $description.trim()
}

# Collects meta tags from $html into hashtables.
function meta_tags($html) {
    $tags = @()
    $meta = ([regex]'<meta [^>]+>').matches($html)
    $meta | ForEach-Object {
        $attrs = ([regex]'([\w-]+)="([^"]+)"').matches($_.value)
        $hash = @{}
        $attrs | ForEach-Object {
            $hash[$_.groups[1].value] = $_.groups[2].value
        }
        $tags += $hash
    }
    $tags
}

function meta_content($tags, $attribute, $search) {
    if(!$tags) { return }
    return $tags | Where-Object { $_[$attribute] -eq $search } | ForEach-Object { $_['content'] }
}

# Looks for a redirect URL in a <meta> refresh tag.
function meta_refresh($tags, $url) {
    $refresh = meta_content $tags 'http-equiv' 'refresh'
    if($refresh) {
        if($refresh -match '\d+;\s*url\s*=\s*(.*)') {
            $refresh_url = $matches[1].trim("'", '"')
            if($refresh_url -notmatch '^https?://') {
                $refresh_url = "$url$refresh_url"
            }
            return $refresh_url
        }
    }
}

function html_body($html) {
    if($html -match '(?s)<body[^>]*>(.*?)</body>') {
        $body = $matches[1]
        $body = $body -replace '(?s)<script[^>]*>.*?</script>', ' '
        $body = $body -replace '(?s)<!--.*?-->', ' '
        return $body
    }
}

function html_text($body, $meta_tags) {
    $body = html_body $html
    if($body) {
        return strip_html $body
    }
}

function strip_html($html) {
    $html = $html -replace '(?s)<[^>]*>', ' '
    $html = $html -replace '\t', ' '
    $html = $html -replace '&nbsp;?', ' '
    $html = $html -replace '&gt;?', '>'
    $html = $html -replace '&lt;?', '<'
    $html = $html -replace '&quot;?', '"'

    $encoding_meta = meta_content $meta_tags 'http-equiv' 'Content-Type'
    if($encoding_meta) {
        if($encoding_meta -match 'charset\s*=\s*(.*)') {
            $charset = $matches[1]
            try {
                $encoding = [text.encoding]::getencoding($charset)
            } catch {
                Write-Warning "Unknown charset"
            }
            if($encoding) {
                $html = ([regex]'&#(\d+);?').replace($html, {
                    param($m)
                    try {
                        return $encoding.getstring($m.Groups[1].Value)
                    } catch {
                        return $m.value
                    }
                })
            }
        }
    }

    $html = $html -replace '\n +', "`r`n"
    $html = $html -replace '\n{2,}', "`r`n"
    $html = $html -replace ' {2,}', ' '
    $html = $html -replace ' (\.|,)', '$1'
    return $html.trim()
}

function find_is($text) {
    if($text -match '(?s)[\n\.]((?:[^\n\.])+? is .+?[\.!])') {
        return $matches[1].trim()
    }
}

function first_para($html) {
    $body = html_body $html
    if($body -match '(?s)<p[^>]*>(.*?)</p>') {
        return strip_html $matches[1]
    }
}
