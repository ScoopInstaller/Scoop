BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
}

Describe 'Test-Aria2Enabled' -Tag 'Scoop' {
    It 'should return true if aria2 is installed' {
        Mock Test-HelperInstalled { $true }
        Mock get_config { $true }
        Test-Aria2Enabled | Should-BeTrue
    }

    It 'should return false if aria2 is not installed' {
        Mock Test-HelperInstalled { $false }
        Mock get_config { $false }
        Test-Aria2Enabled | Should-BeFalse

        Mock Test-HelperInstalled { $false }
        Mock get_config { $true }
        Test-Aria2Enabled | Should-BeFalse

        Mock Test-HelperInstalled { $true }
        Mock get_config { $false }
        Test-Aria2Enabled | Should-BeFalse
    }
}

Describe 'New-DownloadRequest Accept header' -Tag 'Scoop' {
    BeforeAll {
        Mock Get-UserAgent { 'Scoop-Test' }
        Mock Get-GitHubToken { 'fake-token' }
        Mock get_config { }
    }

    It 'omits the Accept header for an Actions artifact zip so it is not rejected with 415' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207/zip'
        $req.Accept | Should-BeNull
    }

    It 'omits the Accept header for an artifact zip even when a filename-override fragment is appended' {
        # Exercises the $reqUrl fragment-strip + Accept-check interaction (the original bug)
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207/zip#/example.zip'
        $req.Accept | Should-BeNull
    }

    It 'sets octet-stream Accept for a release asset so it returns the binary' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/releases/assets/599854636'
        $req.Accept | Should-Be 'application/octet-stream'
    }

    It 'sets octet-stream Accept for other api.github.com paths' {
        $req = New-DownloadRequest 'https://api.github.com/repos/example/example/actions/artifacts/11138249207'
        $req.Accept | Should-Be 'application/octet-stream'
    }
}

Describe 'url_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can be tricked with a hash to override the real filename' {
        url_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo.zip'
    }
}

Describe 'url_remote_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_remote_filename 'http://example.org/foo.txt' | Should-Be 'foo.txt'
        url_remote_filename 'http://example.org/foo.txt?var=123' | Should-Be 'foo.txt'
    }

    It 'can not be tricked with a hash to override the real filename' {
        url_remote_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should-Be 'foo-v2.zip'
    }
}

Describe 'Invoke-CachedDownload' -Tag 'Scoop' {
    BeforeAll {
        $testCache = Join-Path ([IO.Path]::GetTempPath()) "ScoopTestCache_$([Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $testCache -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $testCache) {
            Remove-Item -Recurse -Force $testCache
        }
    }

    It 're-downloads when an interrupted aria2 download left a control file' {
        $url = 'http://example.org/interrupted.zip'
        $cachedir = $testCache
        $cached = cache_path 'testapp' '1.0' $url
        Set-Content -Path $cached -Value 'partial-content' -NoNewline
        Set-Content -Path "$cached.aria2" -Value 'aria2-control' -NoNewline

        Mock Start-Download { param($url, $to, $cookies) Set-Content -Path $to -Value 'complete-content' -NoNewline }

        Invoke-CachedDownload 'testapp' '1.0' $url $null | Should-BeNull

        Should-Invoke Start-Download -Times 1 -Exactly
        (Get-Content -Path $cached -Raw) | Should-Be 'complete-content'
        "$cached.aria2"     }

    It 'keeps the interruption markers when the re-download fails' {
        $url = 'http://example.org/retryfail.zip'
        $cachedir = $testCache
        $cached = cache_path 'testapp' '1.0' $url
        Set-Content -Path $cached -Value 'partial-content' -NoNewline
        Set-Content -Path "$cached.aria2" -Value 'aria2-control' -NoNewline

        Mock Start-Download { throw 'network is down' }

        { Invoke-CachedDownload 'testapp' '1.0' $url $null } | Should-Throw

        # The markers must survive a failed retry so the next run downloads
        # again instead of treating the leftover partial file as a cache hit
        (Test-Path -LiteralPath "$cached.aria2") | Should-BeTrue
        (Get-Content -Path $cached -Raw) | Should-Be 'partial-content'
    }

    It 're-downloads when a previous download left a temp file behind' {
        $url = 'http://example.org/tempfile.zip'
        $cachedir = $testCache
        $cached = cache_path 'testapp' '1.0' $url
        Set-Content -Path $cached -Value 'partial-content' -NoNewline
        Set-Content -Path "$cached.download" -Value 'temp-content' -NoNewline

        Mock Start-Download { param($url, $to, $cookies) Set-Content -Path $to -Value 'complete-content' -NoNewline }

        Invoke-CachedDownload 'testapp' '1.0' $url $null | Should-BeNull

        Should-Invoke Start-Download -Times 1 -Exactly
        (Get-Content -Path $cached -Raw) | Should-Be 'complete-content'
        "$cached.download"     }

    It 'uses the cache when the download is complete' {
        $url = 'http://example.org/complete.zip'
        $cachedir = $testCache
        $cached = cache_path 'testapp' '1.0' $url
        Set-Content -Path $cached -Value 'cached-content' -NoNewline

        Mock Start-Download { param($url, $to, $cookies) Set-Content -Path $to -Value 'complete-content' -NoNewline }

        Invoke-CachedDownload 'testapp' '1.0' $url $null | Should-BeNull

        Should-NotInvoke Start-Download
        (Get-Content -Path $cached -Raw) | Should-Be 'cached-content'
    }
}

Describe 'check_hash' -Tag 'Scoop' {
    BeforeAll {
        $testDir = Join-Path ([IO.Path]::GetTempPath()) "ScoopTestHash_$([Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $wrongHash = 'sha256:' + ('a' * 64)
    }

    AfterAll {
        if (Test-Path $testDir) {
            Remove-Item -Recurse -Force $testDir
        }
    }

    It 'reports an interrupted download as incomplete instead of a hash mismatch' {
        $url = 'http://example.org/interrupted.zip'
        $file = Join-Path $testDir 'interrupted.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        [IO.File]::WriteAllBytes("$file.aria2", [byte[]](1..4))

        $ok, $err, $reason = check_hash $file $wrongHash 'testapp'

        $ok | Should-BeFalse
        $err | Should-MatchString 'Download incomplete'
        $reason | Should-Be 'download incomplete'
    }

    It 'reports a truncated download as incomplete instead of a hash mismatch' {
        $url = 'http://example.org/truncated.zip'
        $file = Join-Path $testDir 'truncated.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        Mock Get-RemoteFileSize { 1000 }

        $ok, $err, $reason = check_hash $file $wrongHash 'testapp'

        $ok | Should-BeFalse
        $err | Should-MatchString 'Download incomplete'
        $reason | Should-Be 'download incomplete'
    }

    It 'still reports a genuine hash mismatch' {
        $url = 'http://example.org/mismatch.zip'
        $file = Join-Path $testDir 'mismatch.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        Mock Get-RemoteFileSize { 10 }

        $ok, $err, $reason = check_hash $file $wrongHash 'testapp'

        $ok | Should-BeFalse
        $err | Should-MatchString 'Hash check failed'
        $reason | Should-Be 'hash check failed'
    }
}

Describe 'is_download_incomplete' -Tag 'Scoop' {
    BeforeAll {
        $testDir = Join-Path ([IO.Path]::GetTempPath()) "ScoopTestIncomplete_$([Guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $testDir) {
            Remove-Item -Recurse -Force $testDir
        }
    }

    It 'detects a local file smaller than the remote one' {
        $file = Join-Path $testDir 'small.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        Mock Get-RemoteFileSize { 1000 }

        is_download_incomplete $file 'http://example.org/small.zip' | Should-BeTrue
    }

    It 'detects a zero-byte download as incomplete' {
        $file = Join-Path $testDir 'empty.zip'
        [IO.File]::WriteAllBytes($file, [byte[]]@())
        Mock Get-RemoteFileSize { 1000 }

        is_download_incomplete $file 'http://example.org/empty.zip' | Should-BeTrue
    }

    It 'returns false when the local file matches the remote size' {
        $file = Join-Path $testDir 'match.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        Mock Get-RemoteFileSize { 10 }

        is_download_incomplete $file 'http://example.org/match.zip' | Should-BeFalse
    }

    It 'returns false when the remote size is unavailable' {
        $file = Join-Path $testDir 'unknown.zip'
        [IO.File]::WriteAllBytes($file, [byte[]](1..10))
        Mock Get-RemoteFileSize { throw 'network error' }

        is_download_incomplete $file 'http://example.org/unknown.zip' | Should-BeFalse
    }
}
