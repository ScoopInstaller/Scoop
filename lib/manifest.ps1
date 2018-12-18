. "$PSScriptRoot\core.ps1"
. "$PSScriptRoot\autoupdate.ps1"

$INSTALL_FILE = 'install.json'
$MANIFEST_FILE = 'manifest.json'

<#
.SYNOPSIS
    Test if there is manifest with all specific extensions. If so return it.
.PARAMETER Path
    Path to manifest without file extension.
#>
function Scoop-GetCorrectManifestExtension {
    param([String] $Path)

    if (Test-Path "$Path.yaml") {
        $Path += '.yaml'
    } elseif (Test-Path "$Path.yml") {
        $Path += '.yml'
    } else {
        $Path += '.json'
    }

    return $Path
}

function manifest_path($app, $bucket) {
    $bucketDirectory = bucketdir $bucket
    $man = sanitary_path $app
    $path = Scoop-GetCorrectManifestExtension "$bucketDirectory\$man"

    return fullpath $path
}

function parse_json($path) {
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
}

function parse_yaml($path) {
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Yaml -Ordered -ErrorAction Stop
}

function Get-Extension {
    param([String] $Path)

    return ((Split-Path $Path -Leaf) -split '\.')[-1]
}

function Is-Yaml {
    param([String] $Extension)

    return ($Extension -like '*yml') -or ($Extension -like '*yaml')
}

<#
.SYNOPSIS
    Parse manifest from given path and returns adequate hashtable.
#>
function Scoop-ParseManifest {
    param([String] $Path)

    if (!(Test-Path $Path)) { return $null }

    if (Is-Yaml (Get-Extension $Path)) {
        return parse_yaml $path
    }

    # Fallback to json
    return parse_json $Path
}

<#
.SYNOPSIS
    Write manifest to file.
.PARAMETER Path
    Manifest to write.
.PARAMETER Content
    Hashtable representation of manifest.
#>
function Scoop-WriteManifest {
    param([String] $Path, $Content)

    if (Is-Yaml $path) {
        $Content = $Content | ConvertTo-Yaml
    } else {
        $Content = $Content | ConvertToPrettyJson
    }

    # Remove potentional empty lines
    $content = $content.Trim()

    [System.IO.File]::WriteAllLines($path, $Content)
}

function url_manifest($url) {
    $str = $null
    try {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $str = $wc.DownloadString($url)
    } catch [System.Management.Automation.MethodInvocationException] {
        warn "error: $($_.Exception.InnerException.Message)"
    } catch {
        throw
    }
    if (!$str) { return $null }

    if (Is-Yaml $url) {
        $str = $str | ConvertFrom-Yaml -Ordered
    } else {
        $str = $str | ConvertFrom-Json
    }

    return $str
}

function manifest($app, $bucket, $url) {
    if ($url) { return url_manifest $url }
    return Scoop-ParseManifest (manifest_path $app $bucket)
}

function save_installed_manifest($app, $bucket, $dir, $url) {
    $cont = $null
    if ($url) {
        $wc = New-Object Net.Webclient
        $wc.Headers.Add('User-Agent', (Get-UserAgent))
        $cont = $wc.DownloadString($url)
        if (Is-Yaml $url) {
            $cont = $cont | ConvertFrom-Yaml
        }
    } else {
        $manifest = manifest_path $app $bucket
        $cont = Scoop-ParseManifest $manifest
    }
    $cont = $cont | ConvertToPrettyJson

    Set-Content "$dir\$MANIFEST_FILE" $cont -Encoding UTF8
}

function installed_manifest($app, $version, $global) {
    return Scoop-ParseManifest "$(versiondir $app $version $global)\$MANIFEST_FILE"
}

function save_install_info($info, $dir) {
    $nulls = $info.keys | Where-Object { $null -eq $info[$_] }
    $nulls | ForEach-Object { $info.remove($_) } # strip null-valued

    Scoop-WriteManifest "$dir\$INSTALL_FILE" $info
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
        $manifest.architecture = [pscustomobject] $manifest.architecture # Fix for yaml
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
