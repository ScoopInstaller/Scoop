function manifest_path($app, $bucket) {
    fullpath "$(Find-BucketDirectory $bucket)\$(sanitary_path $app).json"
}

function parse_json($path) {
    if(!(test-path $path)) { return $null }
    Get-Content $path -raw -Encoding UTF8 | convertfrom-json -ea stop
}

function url_manifest($url) {
    $str = $null
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $str = $wc.downloadstring($url)
    } catch [system.management.automation.methodinvocationexception] {
        warn "error: $($_.exception.innerexception.message)"
    } catch {
        throw
    }
    if(!$str) { return $null }
    $str | convertfrom-json
}

function Get-Manifest($app) {
    $bucket, $manifest, $url = $null
    # check if app is a URL or UNC path
    if ($app -match '^(ht|f)tps?://|\\\\') {
        $url = $app
        $app = appname_from_url $url
        $manifest = url_manifest $url
    } else {
        $app, $bucket, $version = parse_app $app
        if ($bucket) {
            $manifest = manifest $app $bucket
        } else {
            foreach ($bucket in Get-LocalBucket) {
                $manifest = manifest $app $bucket
                if ($manifest) {
                    break
                }
            }
        }
        if (!$manifest) {
            # couldn't find app in buckets: check if it's a local path
            $appPath = $app
            if (!$appPath.EndsWith('.json')) {
                $appPath += '.json'
            }
            if (Test-Path $appPath) {
                $url = Convert-Path $appPath
                $app = appname_from_url $url
                $manifest = url_manifest $url
            }
        }
    }
    return $app, $manifest, $bucket, $url
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }
    parse_json (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if ($url) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $wc.downloadstring($url) > "$dir\manifest.json"
    } else {
        Copy-Item (manifest_path $app $bucket) "$dir\manifest.json"
    }
}

function installed_manifest($app, $version, $global) {
    parse_json "$(versiondir $app $version $global)\manifest.json"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    $file_content = $info | ConvertToPrettyJson # in 'json.ps1'
    [System.IO.File]::WriteAllLines("$dir\install.json", $file_content)
}

function install_info($app, $version, $global) {
    $path = "$(versiondir $app $version $global)\install.json"
    if (!(Test-Path $path)) { return $null }
    parse_json $path
}

function default_architecture {
    $arch = get_config 'default_architecture'
    $system = if ([Environment]::Is64BitOperatingSystem) { '64bit' } else { '32bit' }
    if ($null -eq $arch) {
        $arch = $system
    } else {
        try {
            $arch = ensure_architecture $arch
        } catch {
            warn 'Invalid default architecture configured. Determining default system architecture'
            $arch = $system
        }
    }

    return $arch
}

function arch_specific($prop, $manifest, $architecture) {
    if ($manifest.architecture) {
        $val = $manifest.architecture.$architecture.$prop
        if ($val) { return $val } # else fallback to generic prop
    }

    if ($manifest.$prop) { return $manifest.$prop }
}

function supports_architecture($manifest, $architecture) {
    return -not [String]::IsNullOrEmpty((arch_specific 'url' $manifest $architecture))
}

function generate_user_manifest($app, $bucket, $version) {
    # 'autoupdate.ps1' 'buckets.ps1' 'manifest.ps1'
    $app, $manifest, $bucket, $null = Get-Manifest "$bucket/$app"
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }
    warn "Given version ($version) does not match manifest ($($manifest.version))"
    warn "Attempting to generate manifest for '$app' ($version)"

    if (!($manifest.autoupdate)) {
        abort "'$app' does not have autoupdate capability`r`ncouldn't find manifest for '$app@$version'"
    }

    ensure $(usermanifestsdir) | out-null
    try {
        Invoke-AutoUpdate $app "$(resolve-path $(usermanifestsdir))" $manifest $version $(@{ })
        return "$(resolve-path $(usermanifest $app))"
    } catch {
        write-host -f darkred "Could not install $app@$version"
    }

    return $null
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function msi($manifest, $arch) { arch_specific 'msi' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }
function extract_dir($manifest, $arch) { arch_specific 'extract_dir' $manifest $arch}
function extract_to($manifest, $arch) { arch_specific 'extract_to' $manifest $arch}
