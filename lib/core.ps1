# Note: The default directory changed from ~/AppData/Local/scoop to ~/scoop
#       on 1 Nov, 2016 to work around long paths used by NodeJS.
#       Old installations should continue to work using the old path.
#       There is currently no automatic migration path to deal
#       with updating old installations to the new path.
$scoopdir = $env:SCOOP, "$env:USERPROFILE\scoop" | select -first 1

$oldscoopdir = "$env:LOCALAPPDATA\scoop"
if((test-path $oldscoopdir) -and !$env:SCOOP) {
    $scoopdir = $oldscoopdir
}

$globaldir = $env:SCOOP_GLOBAL, "$env:ProgramData\scoop" | select -first 1

# Note: Setting the SCOOP_CACHE environment variable to use a shared directory
#       is experimental and untested. There may be concurrency issues when
#       multiple users write and access cached files at the same time.
#       Use at your own risk.
$cachedir = $env:SCOOP_CACHE, "$scoopdir\cache" | select -first 1

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }

function format($str, $hash) {
    $hash.keys | % { set-variable $_ $hash[$_] }
    $executionContext.invokeCommand.expandString($str)
}
function is_admin {
    $admin = [security.principal.windowsbuiltinrole]::administrator
    $id = [security.principal.windowsidentity]::getcurrent()
    ([security.principal.windowsprincipal]($id)).isinrole($admin)
}

# messages
function abort($msg) { write-host $msg -f darkred; exit 1 }
function error($msg) { write-host $msg -f darkred }
function warn($msg) { write-host $msg -f darkyellow }
function success($msg) { write-host $msg -f darkgreen }

function filesize($length) {
    $gb = [math]::pow(2, 30)
    $mb = [math]::pow(2, 20)
    $kb = [math]::pow(2, 10)

    if($length -gt $gb) {
        "{0:n1} GB" -f ($length / $gb)
    } elseif($length -gt $mb) {
        "{0:n1} MB" -f ($length / $mb)
    } elseif($length -gt $kb) {
        "{0:n1} KB" -f ($length / $kb)
    } else {
        "$($length) B"
    }
}

# dirs
function basedir($global) { if($global) { return $globaldir } $scoopdir }
function appsdir($global) { "$(basedir $global)\apps" }
function shimdir($global) { "$(basedir $global)\shims" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }
function persistdir($app, $global) { "$(basedir $global)\persist\$app" }
function usermanifestsdir { "$(basedir)\workspace" }
function usermanifest($app) { "$(usermanifestsdir)\$app.json" }
function cache_path($app, $version, $url) { "$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')" }

# apps
function sanitary_path($path) { return [regex]::replace($path, "[/\\?:*<>|]", "") }
function installed($app, $global=$null) {
    if($global -eq $null) { return (installed $app $true) -or (installed $app $false) }
    return is_directory (appdir $app $global)
}
function installed_apps($global) {
    $dir = appsdir $global
    if(test-path $dir) {
        gci $dir | where { $_.psiscontainer -and $_.name -ne 'scoop' } | % { $_.name }
    }
}

function app_status($app, $global) {
    $status = @{}
    $status.installed = (installed $app $global)
    $status.version = current_version $app $global
    $status.latest_version = $status.version

    $install_info = install_info $app $status.version $global

    $status.failed = (!$install_info -or !$status.version)

    $manifest = manifest $app $install_info.bucket $install_info.url
    $status.removed = (!$manifest)
    if($manifest.version) {
        $status.latest_version = $manifest.version
    }

    $status.outdated = $false
    if($status.version -and $status.latest_version) {
        $status.outdated = ((compare_versions $status.latest_version $status.version) -gt 0)
    }

    $status.missing_deps = @()
    $deps = @(runtime_deps $manifest) | ? { !(installed $_) }
    if($deps) {
        $status.missing_deps += ,$deps
    }

    return $status
}

function appname_from_url($url) {
    (split-path $url -leaf) -replace '.json$', ''
}

# paths
function fname($path) { split-path $path -leaf }
function strip_ext($fname) { $fname -replace '\.[^\.]*$', '' }
function strip_filename($path) { $path -replace [regex]::escape((fname $path)) }
function strip_fragment($url) { $url -replace (new-object uri $url).fragment }

function url_filename($url) {
    (split-path $url -leaf).split('?') | Select-Object -First 1
}
# Unlike url_filename which can be tricked by appending a
# URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
# this function extracts the original filename from the URL.
function url_remote_filename($url) {
    split-path (new-object uri $url).absolutePath -leaf
}

function ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
function fullpath($path) { # should be ~ rooted
    $executionContext.sessionState.path.getUnresolvedProviderPathFromPSPath($path)
}
function relpath($path) { "$($myinvocation.psscriptroot)\$path" } # relative to calling script
function friendly_path($path) {
    $h = (Get-PsProvider 'FileSystem').home; if(!$h.endswith('\')) { $h += '\' }
    if($h -eq '\') { return $path }
    return "$path" -replace ([regex]::escape($h)), "~\"
}
function is_local($path) {
    ($path -notmatch '^https?://') -and (test-path $path)
}

# operations
function dl($url,$to) {
    $wc = new-object system.net.webClient
    $wc.headers.add('User-Agent', 'Scoop/1.0')
    $wc.headers.add('Referer', (strip_filename $url))
    $wc.downloadFile($url,$to)
}

function env($name,$global,$val='__get') {
    $target = 'User'; if($global) {$target = 'Machine'}
    if($val -eq '__get') { [environment]::getEnvironmentVariable($name,$target) }
    else { [environment]::setEnvironmentVariable($name,$val,$target) }
}

function unzip($path,$to) {
    if(!(test-path $path)) { abort "can't find $path to unzip"}
    try { add-type -assembly "System.IO.Compression.FileSystem" -ea stop }
    catch { unzip_old $path $to; return } # for .net earlier than 4.5
    try {
        [io.compression.zipfile]::extracttodirectory($path,$to)
    } catch [system.io.pathtoolongexception] {
        # try to fall back to 7zip if path is too long
        if(7zip_installed) {
            extract_7zip $path $to $false
            return
        } else {
            abort "Unzip failed: Windows can't handle the long paths in this zip file.`nRun 'scoop install 7zip' and try again."
        }
    } catch {
        abort "Unzip failed: $_"
    }
}

function unzip_old($path,$to) {
    # fallback for .net earlier than 4.5
    $shell = (new-object -com shell.application -strict)
    $zipfiles = $shell.namespace("$path").items()
    $to = ensure $to
    $shell.namespace("$to").copyHere($zipfiles, 4) # 4 = don't show progress dialog
}

function is_directory([String] $path) {
    return (Test-Path $path) -and (Get-Item $path) -is [System.IO.DirectoryInfo]
}

function movedir($from, $to) {
    $from = $from.trimend('\')
    $to = $to.trimend('\')

    $out = robocopy "$from" "$to" /e /move
    if($lastexitcode -ge 8) {
        throw "Error moving directory: `n$out"
    }
}

function shim($path, $global, $name, $arg) {
    if(!(test-path $path)) { abort "Can't shim '$(fname $path)': couldn't find '$path'." }
    $abs_shimdir = ensure (shimdir $global)
    if(!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower()).ps1"

    # convert to relative path
    pushd $abs_shimdir
    $relpath = resolve-path -relative $path
    popd

    # if $path points to another drive resolve-path prepends .\ which could break shims
    if($relpath -match "^(.\\[\w]:).*$") {
        write-output "`$path = `"$path`"" | out-file $shim -encoding utf8
    } else {
        write-output "`$path = join-path `"`$psscriptroot`" `"$relpath`"" | out-file $shim -encoding utf8
    }

    if($arg) {
        write-output "`$args = '$($arg -join "', '")', `$args" | out-file $shim -encoding utf8 -append
    }
    write-output 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' | out-file $shim -encoding utf8 -append

    if($path -match '\.exe$') {
        # for programs with no awareness of any shell
        $shim_exe = "$(strip_ext($shim)).shim"
        cp "$(versiondir 'scoop' 'current')\supporting\shimexe\shim.exe" "$(strip_ext($shim)).exe" -force
        write-output "path = $(resolve-path $path)" | out-file $shim_exe -encoding utf8
        if($arg) {
            write-output "args = $arg" | out-file $shim_exe -encoding utf8 -append
        }
    } elseif($path -match '\.((bat)|(cmd))$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        $shim_cmd = "$(strip_ext($shim)).cmd"
        "@`"$(resolve-path $path)`" $arg %*" | out-file $shim_cmd -encoding ascii
    } elseif($path -match '\.ps1$') {
        # make ps1 accessible from cmd.exe
        $shim_cmd = "$(strip_ext($shim)).cmd"

"@echo off
setlocal enabledelayedexpansion
set args=%*
:: replace problem characters in arguments
set args=%args:`"='%
set args=%args:(=``(%
set args=%args:)=``)%
set invalid=`"='
if !args! == !invalid! ( set args= )
powershell -noprofile -ex unrestricted `"& '$(resolve-path $path)' %args%;exit `$lastexitcode`"" | out-file $shim_cmd -encoding ascii
    }
}

function ensure_in_path($dir, $global) {
    $path = env 'PATH' $global
    $dir = fullpath $dir
    if($path -notmatch [regex]::escape($dir)) {
        write-output "Adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path."

        env 'PATH' $global "$dir;$path" # for future sessions...
        $env:PATH = "$dir;$env:PATH" # for this session
    }
}

function ensure_architecture($architecture_opt) {
    if(!$architecture_opt) {
        return default_architecture
    }
    $architecture_opt = $architecture_opt.ToString().ToLower()
    switch($architecture_opt) {
        { @('64bit', '64', 'x64', 'amd64', 'x86_64', 'x86-64')  -contains $_ } { return '64bit' }
        { @('32bit', '32', 'x86', 'i386', '386', 'i686')  -contains $_ } { return '32bit' }
        default { throw [System.ArgumentException] "Invalid architecture: '$architecture_opt'"}
    }
}

function ensure_all_installed($apps, $global) {
    $installed = @()
    $apps | Select-Object -Unique | Where-Object { $_.name -ne 'scoop' } | % {
        $app = $_
        if(installed $app $false) {
            $installed += ,@($app, $false)
        } elseif (installed $app $true) {
            if($global) {
                $installed += ,@($app, $true)
            } else {
                error "'$app' isn't installed for your account, but it is installed globally."
                warn "Try again with the --global (or -g) flag instead."
            }
        } else {
            error "'$app' isn't installed."
        }
    }
    return ,$installed
}

function strip_path($orig_path, $dir) {
    if($orig_path -eq $null) { $orig_path = '' }
    $stripped = [string]::join(';', @( $orig_path.split(';') | ? { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
}

function remove_from_path($dir,$global) {
    $dir = fullpath $dir

    # future sessions
    $was_in_path, $newpath = strip_path (env 'path' $global) $dir
    if($was_in_path) {
        write-output "Removing $(friendly_path $dir) from your path."
        env 'path' $global $newpath
    }

    # current session
    $was_in_path, $newpath = strip_path $env:PATH $dir
    if($was_in_path) { $env:PATH = $newpath }
}

function ensure_scoop_in_path($global) {
    $abs_shimdir = ensure (shimdir $global)
    # be aggressive (b-e-aggressive) and install scoop first in the path
    ensure_in_path $abs_shimdir $global
}

function ensure_robocopy_in_path {
    if(!(gcm robocopy -ea ignore)) {
        shim "C:\Windows\System32\Robocopy.exe" $false
    }
}

function wraptext($text, $width) {
    if(!$width) { $width = $host.ui.rawui.windowsize.width };
    $width -= 1 # be conservative: doesn't seem to print the last char

    $text -split '\r?\n' | % {
        $line = ''
        $_ -split ' ' | % {
            if($line.length -eq 0) { $line = $_ }
            elseif($line.length + $_.length + 1 -le $width) { $line += " $_" }
            else { $lines += ,$line; $line = $_ }
        }
        $lines += ,$line
    }

    $lines -join "`n"
}

function pluralize($count, $singular, $plural) {
    if($count -eq 1) { $singular } else { $plural }
}

# for dealing with user aliases
$default_aliases = @{
    'cp' = 'copy-item'
    'echo' = 'write-output'
    'gc' = 'get-content'
    'gci' = 'get-childitem'
    'gcm' = 'get-command'
    'gm' = 'get-member'
    'iex' = 'invoke-expression'
    'ls' = 'get-childitem'
    'mkdir' = { new-item -type directory @args }
    'mv' = 'move-item'
    'rm' = 'remove-item'
    'sc' = 'set-content'
    'select' = 'select-object'
    'sls' = 'select-string'
}

function reset_alias($name, $value) {
    if($existing = get-alias $name -ea ignore |? { $_.options -match 'readonly' }) {
        if($existing.definition -ne $value) {
            write-host "Alias $name is read-only; can't reset it." -f darkyellow
        }
        return # already set
    }
    if($value -is [scriptblock]) {
        if(!(test-path -path "function:script:$name")) {
            new-item -path function: -name "script:$name" -value $value | out-null
        }
        return
    }

    set-alias $name $value -scope script -option allscope
}

function reset_aliases() {
    # for aliases where there's a local function, re-alias so the function takes precedence
    $aliases = get-alias |? { $_.options -notmatch 'readonly|allscope' } |% { $_.name }
    get-childitem function: | % {
        $fn = $_.name
        if($aliases -contains $fn) {
            set-alias $fn local:$fn -scope script
        }
    }

    # set default aliases
    $default_aliases.keys | % { reset_alias $_ $default_aliases[$_] }
}

# convert list of apps to list of ($app, $global) tuples
function applist($apps, $global) {
    if(!$apps) { return @() }
    return ,@($apps |% { ,@($_, $global) })
}

function app($app) {
    $app = [string]$app
    if($app -notmatch '^((ht)|f)tps?://') {
        if($app -match '([a-zA-Z0-9-]+)/([a-zA-Z0-9-]+)') {
            return $matches[2], $matches[1]
        }
    }

    $app, $null
}

function is_app_with_specific_version([String] $app) {
    $appWithVersion = get_app_with_version $app
    $appWithVersion.version -ne 'latest'
}

function get_app_with_version([String] $app) {
    $segments = $app -split '@'
    $name     = $segments[0]
    $version  = $segments[1];

    return @{
        "app" = $name;
        "version" = if ($version) { $version } else { 'latest' }
    }
}
function is_scoop_outdated() {
    $now = Get-Date
    try {
        $last_update = (Get-Date $(scoop config lastupdate)).ToLocalTime().AddHours(3)
    } catch {
        scoop config lastupdate $now
        # remove 1 minute to force an update for the first time
        $last_update = $now.AddMinutes(-1)
    }
    return $last_update -lt  $now.ToLocalTime()
}

function substitute([String] $str, [Hashtable] $params) {
    $params.GetEnumerator() | % {
        $str = $str.Replace($_.Name, $_.Value)
    }
    return $str
}

function format_hash([String] $hash) {
    switch ($hash.Length)
    {
        32 { $hash = "md5:$hash" } # md5
        40 { $hash = "sha1:$hash" } # sha1
        64 { $hash = $hash } # sha256
        128 { $hash = "sha512:$hash" } # sha512
        default { $hash = $null }
    }
    return $hash
}

function handle_special_urls($url)
{
    # FossHub.com
    if($url -match "^(.*fosshub.com\/)(?<name>.*)\/(?<filename>.*)$") {
        # create an url to request to request the expiring url
        $name = $matches['name'] -replace '.html',''
        $filename = $matches['filename']
        # the key is a random 24 chars long hex string, so lets use ' SCOOPSCOOP ' :)
        $url = "https://www.fosshub.com/gensLink/$name/$filename/2053434f4f5053434f4f5020"
        $url = (Invoke-WebRequest -Uri $url | Select-Object -ExpandProperty Content)
    }
    return $url
}
