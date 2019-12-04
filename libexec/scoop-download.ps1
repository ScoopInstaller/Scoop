# Usage: scoop download <app> [options]
# Summary: Download manifest files into cache folder.
#
# Help: All manifest files will be downloaded into cache folder.
#
# Options:
#   -s, --skip                      Skip hash check validation.
#   -a, --arch <32bit|64bit>        Use the specified architecture.
#   -u, --utility <native|aria2>    Force using specific download utility.
#   -b, --all-architectures         All avaible files across all architectures will be downloaded.

@('getopt', 'help', 'install', 'manifest') | ForEach-Object {
    . "$PSScriptRoot\..\lib\$_.ps1"
}

reset_aliases

#region Parameter validation
$opt, $application, $err = getopt $args 'sba:u:' 'skip', 'all-architectures', 'arch=', 'utility='
if ($err) {
    # TODO: Stop-ScoopExecution
    error "scoop install: $err"
    exit 1
}

$checkHash = -not ($opt.s -or $opt.skip)
$utility = $opt.u, $opt.utility, 'native' | Where-Object { -not [String]::IsNullOrEmpty($_) } | Select-Object -First 1

try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    # TODO: Stop-ScoopExecution
    abort "ERROR: $_"
}
# Add both architectures
if ($opt.b -or $opt.'all-architectures') { $architecture = '32bit', '64bit' }

if (-not $application) {
    # TODO:? Extend Stop-ScoopExecution with -Usage switch
    error '<app> missing'
    my_usage
    exit 1
}

if (($utility -eq 'aria2') -and (-not (Test-HelperInstalled -Helper Aria2))) {
    # TODO: Stop-ScoopExecution
    abort 'Aria2 is not installed'
}
#endregion Parameter validation

foreach ($app in $application) {
    # Prevent leaking variable from previous iteration
    $cleanAppName, $bucket, $version, $appname, $manifest, $foundBucket, $url = $null, $null, $null, $null, $null, $null, $null

    $cleanAppName, $bucket, $version = parse_app $app
    $appName, $manifest, $foundBucket, $url = Find-Manifest $cleanAppName $bucket

    # Handle potential use case, which should not appear, but just in case
    # If parsed name/bucket is not same as the provided one
    if ((-not $url) -and (($cleanAppName -ne $appName) -or ($bucket -ne $foundBucket))) {
        debug $bucket
        debug $cleanAppName
        debug $foundBucket
        debug $appName
        error 'Found application name or bucket is not same as requested'
        continue
    }

    # Generate manifest if there is different version in manifest
    if (($null -ne $version) -and ($manifest.version -ne $version)) {
        $manifest = parse_json(generate_user_manifest $appName $bucket $version)
    }
    if (-not $version) { $version = $manifest.version }

    # TODO: Rework with proper wrappers after #3149
    switch ($utility) {
        'aria2' {
            foreach ($arch in $architecture) {
                dl_with_cache_aria2 $appName $version $manifest $arch $cachedir $manifest.cookie $true $checkHash
            }
        }

        'native' {
            # $env:SCOOP_DEBUG = $false; scoop cache rm *; .\bin\scoop.ps1 download main/git D:\MEGA\Projects\SCOOPs\Ash258\bucket\Wavebox10.json Ash258/Wavebox@4.10.6 -s
            foreach ($arch in $architecture) {
                foreach ($url in (url $manifest $arch)) {
                    dl_with_cache 'cosi' '1.0' 'https://wavebox.pro/dl/client/4_10_6/Wavebox_4_10_6_windows_x86_64/RELEASES' $null $null $true
                    # dl_with_cache $appName $version $url $null $manifest.cookie $true

                    if ($checkHash) {
                        $manifestHash = hash_for_url $manifest $url $arch
                        $source = cache_path $appName $version $url
                        $ok, $err = check_hash $source $manifestHash (show_app $appName $bucket)

                        if (!$ok) {
                            error $err
                            if (Test-Path $source) { Remove-Item $source -Force }
                            if ($url -like '*sourceforge.net*') {
                                warn 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                            }
                            error (new_issue_msg $appName $bucket 'hash check failed')
                            continue
                        }
                    }
                }
            }
        }

        default {
            # abort could be called without any issue as it is used for all applications
            # TODO: Stop-ScoopExecution
            abort 'Not supported download utility'
        }
    }
}

exit 0
