. "$psscriptroot/core.ps1"
. "$psscriptroot/autoupdate.ps1"

function manifest_path($app, $bucket) {
    "$(bucketdir $bucket)\$(sanitary_path $app).json"
}

function parse_json($path) {
    if(!(test-path $path)) { return $null }
    gc $path -raw -Encoding UTF8 | convertfrom-json -ea stop
}

function url_manifest($url) {
    $str = $null
    try {
        $str = (new-object net.webclient).downloadstring($url)
    } catch [system.management.automation.methodinvocationexception] {
        warn "error: $($_.exception.innerexception.message)"
    } catch {
        throw
    }
    if(!$str) { return $null }
    $str | convertfrom-json
}

function manifest($app, $bucket, $url) {
    if($url) { return url_manifest $url }
    parse_json (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if($url) { (new-object net.webclient).downloadstring($url) > "$dir\manifest.json" }
    else { cp (manifest_path $app $bucket) "$dir\manifest.json" }
}

function installed_manifest($app, $version, $global) {
    parse_json "$(versiondir $app $version $global)\manifest.json"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | ? { $info[$_] -eq $null }
    $nulls | % { $info.remove($_) } # strip null-valued

    $info | convertto-json | out-file "$dir\install.json"
}

function install_info($app, $version, $global) {
    $path = "$(versiondir $app $version $global)\install.json"
    if(!(test-path $path)) { return $null }
    parse_json $path
}

function default_architecture {
    if([intptr]::size -eq 8) { return "64bit" }
    "32bit"
}

function arch_specific($prop, $manifest, $architecture) {
    if($manifest.architecture) {
        $val = $manifest.architecture.$architecture.$prop
        if($val) { return $val } # else fallback to generic prop
    }

    if($manifest.$prop) { return $manifest.$prop }
}

function supports_architecture($manifest, $architecture) {
    return -not [String]::IsNullOrEmpty((arch_specific 'url' $manifest $architecture))
}

function generate_user_manifest($app, $version) {

    $null, $manifest, $bucket, $null = locate $app
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
        autoupdate $app "$(resolve-path $(usermanifestsdir))" $manifest $version $(New-Object HashTable)
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
