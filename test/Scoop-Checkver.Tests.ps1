BeforeAll {
    $checkver = "$PSScriptRoot\..\bin\checkver.ps1"
    $working_dir = "$([IO.Path]::GetTempPath())ScoopTestFixtures\checkver"
    $bucket_dir = "$working_dir\bucket"

    function Get-ManifestVersion($Name) {
        return (Get-Content "$bucket_dir\$Name.json" -Raw | ConvertFrom-Json).version
    }

    # Writes a manifest whose 'checkver' and 'autoupdate.hash' both read from
    # local files, so the round trip runs offline and deterministically.
    function New-TestManifest($Name, $ManifestVersion, $SourceVersion) {
        $source_file = "$working_dir\$Name.version.txt"
        $hash_file = "$working_dir\$Name.hash.txt"
        Set-Content $source_file -Value "version $SourceVersion"
        # A fake but well-formed SHA-256, so 'autoupdate' resolves a hash
        # without downloading anything.
        Set-Content $hash_file -Value ('a' * 64)

        @{
            version     = $ManifestVersion
            description = 'Test manifest'
            homepage    = 'https://example.invalid'
            license     = 'MIT'
            url         = "https://example.invalid/app-$ManifestVersion.zip"
            hash        = '0' * 64
            checkver    = @{
                url   = ([System.Uri]$source_file).AbsoluteUri
                regex = 'version ([\d.]+)'
            }
            autoupdate  = @{
                url  = 'https://example.invalid/app-$version.zip'
                hash = @{ url = ([System.Uri]$hash_file).AbsoluteUri }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content "$bucket_dir\$Name.json"
    }
}

Describe 'checkver' -Tag 'Scoop' {
    BeforeEach {
        if (Test-Path $working_dir) {
            Remove-Item -Recurse -Force $working_dir
        }
        New-Item -ItemType Directory -Path $bucket_dir -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $working_dir) {
            Remove-Item -Recurse -Force $working_dir
        }
    }

    It 'updates the manifest when the source reports a newer version' {
        New-TestManifest -Name 'newer' -ManifestVersion '1.0.0' -SourceVersion '2.0.0'

        & $checkver -App 'newer' -Dir $bucket_dir -Update *>&1 | Out-Null

        Get-ManifestVersion 'newer' | Should -Be '2.0.0'
    }

    It 'leaves the manifest alone when the source reports an older version' {
        New-TestManifest -Name 'older' -ManifestVersion '2.0.0' -SourceVersion '1.0.0'

        $output = & $checkver -App 'older' -Dir $bucket_dir -Update *>&1 | Out-String

        Get-ManifestVersion 'older' | Should -Be '2.0.0'
        $output | Should -Match 'skipping downgrade'
    }

    It 'downgrades the manifest when -ForceUpdate is specified' {
        New-TestManifest -Name 'forced' -ManifestVersion '2.0.0' -SourceVersion '1.0.0'

        & $checkver -App 'forced' -Dir $bucket_dir -ForceUpdate *>&1 | Out-Null

        Get-ManifestVersion 'forced' | Should -Be '1.0.0'
    }

    It 'keeps processing other manifests after skipping a regression' {
        New-TestManifest -Name 'regressed' -ManifestVersion '2.0.0' -SourceVersion '1.0.0'
        New-TestManifest -Name 'upgraded' -ManifestVersion '1.0.0' -SourceVersion '2.0.0'

        $output = & $checkver -Dir $bucket_dir -Update *>&1 | Out-String

        Get-ManifestVersion 'regressed' | Should -Be '2.0.0'
        Get-ManifestVersion 'upgraded' | Should -Be '2.0.0'
        $output | Should -Match 'skipping downgrade'
        $output | Should -Match 'Autoupdating upgraded'
    }
}
