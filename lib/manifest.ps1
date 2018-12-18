. "$PSScriptRoot\core.ps1"
. "$PSScriptRoot\autoupdate.ps1"

$INSTALL_FILE = 'install.json'
$MANIFEST_FILE = 'manifest.json'

function manifest_path($app, $bucket) {
    # TODO: YAML
    fullpath "$(bucketdir $bucket)\$(sanitary_path $app).json"
}

function parse_json($path) {
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
}

<#
.SYNOPSIS
    Parse manifest and return adequate hashtable.
.DESCRIPTION
    Long description
#>
function Scoop-ParseManifest {
    param([String] $Path)

    if (!(Test-Path $Path)) { return $null }
    # TODO: YAML

    return parse_json $Path
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
    # TODO: YAML
    if (!$str) { return $null }
    $str | convertfrom-json
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }
    return Scoop-ParseManifest (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    if ($url) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $cont = $wc.DownloadString($url)
        # TODO: YAML
        # if (Is-Yaml $url) { ConvertFrom-Yaml | ConvertToPrettyJson}

        Set-Content "$dir\$MANIFEST_FILE" $cont -Encoding UTF8
    } else {
        # TODO: YAML
        Copy-Item (manifest_path $app $bucket) "$dir\$MANIFEST_FILE"
    }
}

function installed_manifest($app, $version, $global) {
    return Scoop-ParseManifest "$(versiondir $app $version $global)\$MANIFEST_FILE"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    $file_content = $info | ConvertToPrettyJson
    [System.IO.File]::WriteAllLines("$dir\$INSTALL_FILE", $file_content)
}

function install_info($app, $version, $global) {
    $path = "$(versiondir $app $version $global)\$INSTALL_FILE"
    if (!(test-path $path)) { return $null }
    return Scoop-ParseManifest $path
}

function default_architecture {
    if ([intptr]::Size -eq 8) {
        return '64bit'
    } else {
        return '32bit'
    }
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
    $null, $manifest, $bucket, $null = locate $app $bucket
    if ("$($manifest.version)" -eq "$version") {
        return manifest_path $app $bucket
    }
    warn "Given version ($version) does not match manifest ($($manifest.version))"
    warn "Attempting to generate manifest for '$app' ($version)"

    if (!($manifest.autoupdate)) {
        abort "'$app' does not have autoupdate capability`r`ncouldn't find manifest for '$app@$version'"
    }

    ensure $(usermanifestsdir) | Out-Null
    try {
        autoupdate $app "$(Resolve-Path $(usermanifestsdir))" $manifest $version $(@{})
        return "$(Resolve-Path $(usermanifest $app))"
    } catch {
        Write-Host "Could not install $app@$version" -ForegroundColor DarkRed
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
