# Usage: scoop download <app> [options]
# Summary: Download apps in the cache folder and verify hashes
# Help: e.g. The usual way to download an app, without installing it (uses your local 'buckets'):
#      scoop download git
#
# To download a different version of the app
# (note that this will auto-generate the manifest using current version):
#      scoop download gh@2.7.0
#
# To download an app from a manifest at a URL:
#      scoop download https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/runat.json
#
# To download an app from a manifest on your computer
#      scoop download path\to\app.json
#
# Options:
#   -f, --force                     Force download (overwrite cache)
#   -s, --skip-hash-check           Skip hash verification (use with caution!)
#   -u, --no-update-scoop           Don't update Scoop before downloading if it's outdated
#   -a, --arch <32bit|64bit|arm64>  Use the specified architecture, if the app supports it

. "$PSScriptRoot\..\lib\getopt.ps1"
. "$PSScriptRoot\..\lib\json.ps1" # 'autoupdate.ps1' (indirectly)
. "$PSScriptRoot\..\lib\autoupdate.ps1" # 'generate_user_manifest' (indirectly)
. "$PSScriptRoot\..\lib\manifest.ps1" # 'generate_user_manifest' 'Get-Manifest'
. "$PSScriptRoot\..\lib\download.ps1"
if (get_config USE_SQLITE_CACHE) {
    . "$PSScriptRoot\..\lib\database.ps1"
}

$opt, $apps, $err = getopt $args 'fsua:' 'force', 'skip-hash-check', 'no-update-scoop', 'arch='
if ($err) { error "scoop download: $err"; exit 1 }

$check_hash = !($opt.s -or $opt.'skip-hash-check')
$use_cache = !($opt.f -or $opt.force)
$architecture = Get-DefaultArchitecture
try {
    $architecture = Format-ArchitectureString ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

if (!$apps) { error '<app> missing'; my_usage; exit 1 }

if (is_scoop_outdated) {
    if ($opt.u -or $opt.'no-update-scoop') {
        warn "Scoop is out of date."
    } else {
        & "$PSScriptRoot\scoop-update.ps1"
    }
}

# we only want to show this warning once
if(!$use_cache) { warn "Cache is being ignored." }

foreach ($curr_app in $apps) {
    # Prevent leaking variables from previous iteration
    $bucket = $version = $app = $manifest = $url = $null

    $app, $bucket, $version = parse_app $curr_app
    $app, $manifest, $bucket, $url = Get-Manifest "$bucket/$app"

    info "Downloading '$app'$(if ($version) { " ($version)" }) [$architecture]$(if ($bucket) { " from $bucket bucket" })"

    # Generate manifest if there is different version in manifest
    if (($null -ne $version) -and ($manifest.version -ne $version)) {
        $generated = generate_user_manifest $app $bucket $version
        if ($null -eq $generated) {
            error 'Manifest cannot be generated with provided version'
            continue
        }
        $manifest = parse_json($generated)
    }

    if(!$manifest) {
        error "Couldn't find manifest for '$app'$(if($bucket) { " from '$bucket' bucket" } elseif($url) { " at '$url'" })."
        continue
    }
    $version = $manifest.version
    if(!$version) {
        error "Manifest doesn't specify a version."
        continue
    }
    if($version -match '[^\w\.\-\+_]') {
        error "Manifest version has unsupported character '$($matches[0])'."
        continue
    }

    $curr_check_hash = $check_hash
    if ($version -eq 'nightly') {
        $version = nightly_version
        $curr_check_hash = $false
    }

    $architecture = Get-SupportedArchitecture $manifest $architecture
    if ($null -eq $architecture) {
        error "'$app' doesn't support current architecture!"
        continue
    }

    if(Test-Aria2Enabled) {
        Invoke-CachedAria2Download $app $version $manifest $architecture $cachedir $manifest.cookie $use_cache $curr_check_hash
    } else {
        foreach($url in script:url $manifest $architecture) {
            try {
                Invoke-CachedDownload $app $version $url $null $manifest.cookie $use_cache
            } catch {
                write-host -f darkred $_
                error "URL $url is not valid"
                $dl_failure = $true
                continue
            }

            if($curr_check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $cached = cache_path $app $version $url
                $ok, $err = check_hash $cached $manifest_hash (show_app $app $bucket)

                if(!$ok) {
                    error $err
                    if(test-path $cached) {
                        # rm cached file
                        Remove-Item -force $cached
                    }
                    if ($url -like '*sourceforge.net*') {
                        warn 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    error (new_issue_msg $app $bucket "hash check failed")
                    continue
                }
            } else {
                info "Skipping hash verification."
            }
        }
    }

    if (!$dl_failure) {
        success "'$app' ($version) was downloaded successfully!"
    }
}

exit 0
