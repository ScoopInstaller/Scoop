$scoopdir = $env:SCOOP, "~\appdata\local\scoop" | select -first 1
$globaldir = $env:SCOOP_GLOBAL, "$($env:programdata.tolower())\scoop" | select -first 1
$cachedir = "$scoopdir\cache" # always local

$CMDenvpipe = $env:SCOOP__CMDenvpipe

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
function warn($msg) { write-host $msg -f darkyellow; }
function success($msg) { write-host $msg -f darkgreen }

# dirs
function basedir($global) { if($global) { return $globaldir } $scoopdir }
function appsdir($global) { "$(basedir $global)\apps" }
function shimdir($global) { "$(basedir $global)\shims" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }

# apps
function sanitary_path($path) { return [regex]::replace($path, "[/\\?:*<>|]", "") }
function installed($app, $global=$null) {
    if($global -eq $null) { return (installed $app $true) -or (installed $app $false) }
    return test-path (appdir $app $global)
}
function installed_apps($global) {
    $dir = appsdir $global
    if(test-path $dir) {
        gci $dir | where { $_.psiscontainer -and $_.name -ne 'scoop' } | % { $_.name }
    }
}

# paths
function fname($path) { split-path $path -leaf }
function strip_ext($fname) { $fname -replace '\.[^\.]*$', '' }

function ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
function fullpath($path) { # should be ~ rooted
    $executionContext.sessionState.path.getUnresolvedProviderPathFromPSPath($path)
}
function relpath($path) { "$($myinvocation.psscriptroot)\$path" } # relative to calling script
function friendly_path($path) {
    $h = $home; if(!$h.endswith('\')) { $h += '\' }
    return "$path" -replace ([regex]::escape($h)), "~\"
}
function is_local($path) {
    ($path -notmatch '^https?://') -and (test-path $path)
}

# operations
function dl($url,$to) {
    $wc = new-object system.net.webClient
    $wc.headers.add('User-Agent', 'Scoop/1.0')
    $wc.downloadFile($url,$to)

}
function env { param($name,$value,$targetEnvironment)
    if ( $PSBoundParameters.ContainsKey('targetEnvironment') ) {
        # $targetEnvironment is expected to be $null, [bool], [string], or [System.EnvironmentVariableTarget]
        if ($targetEnvironment -eq $null) { $targetEnvironment = [System.EnvironmentVariableTarget]::Process }
        elseif ($targetEnvironment -is [bool]) {
            # from initial usage pattern
            if ($targetEnvironment) { $targetEnvironment = [System.EnvironmentVariableTarget]::Machine }
            else { $targetEnvironment = [System.EnvironmentVariableTarget]::User }
        }
        elseif (($targetEnvironment -eq '') -or ($targetEnvironment -eq 'Process') -or ($targetEnvironment -eq 'Session')) { $targetEnvironment = [System.EnvironmentVariableTarget]::Process }
        elseif ($targetEnvironment -eq 'User') { $targetEnvironment = [System.EnvironmentVariableTarget]::User }
        elseif (($targetEnvironment -eq 'Global') -or ($targetEnvironment -eq 'Machine')) { $targetEnvironment = [System.EnvironmentVariableTarget]::Machine }
        elseif ($targetEnvironment -is [System.EnvironmentVariableTarget]) { <# NoOP #> }
        else {
            throw "ERROR: logic: incorrect targetEnvironment parameter ('$targetEnvironment') used for env()"
        }
    }
    else { $targetEnvironment = [System.EnvironmentVariableTarget]::Process }

    if($PSBoundParameters.ContainsKey('value')) {
        [environment]::setEnvironmentVariable($name,$value,$targetEnvironment)
        if (($targetEnvironment -eq [System.EnvironmentVariableTarget]::Process) -and ($CMDenvpipe -ne $null)) {
            "set " + ( CMD_SET_encode_arg("$name=$value") ) | out-file $CMDenvpipe -encoding OEM -append
        }
    }
    else { [environment]::getEnvironmentVariable($name,$targetEnvironment) }
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
            abort "unzip failed: Windows can't handle the long paths in this zip file.`nrun 'scoop install 7zip' and try again."
        }
    } catch {
        abort "unzip failed: $_"
    }
}
function unzip_old($path,$to) {
    # fallback for .net earlier than 4.5
    $shell = (new-object -com shell.application -strict)
    $zipfiles = $shell.namespace("$path").items()
    $to = ensure $to
    $shell.namespace("$to").copyHere($zipfiles, 4) # 4 = don't show progress dialog
}

function movedir($from, $to) {
    $from = $from.trimend('\')
    $to = $to.trimend('\')

    $out = robocopy "$from" "$to" /e /move
    if($lastexitcode -ge 8) {
        throw "error moving directory: `n$out"
    }
}

function shim($path, $global, $name, $arg) {
    if(!(test-path $path)) { abort "can't shim $(fname $path): couldn't find $path" }
    $abs_shimdir = ensure (shimdir $global)
    if(!$name) { $name = strip_ext (fname $path) }

    $shim = "$abs_shimdir\$($name.tolower()).ps1"

    # convert to relative path
    pushd $abs_shimdir
    $relative_path = resolve-path -relative $path
    popd

    echo '# ensure $HOME is set for MSYS programs' | out-file $shim -encoding oem
    echo "if(!`$env:home) { `$env:home = `"`$home\`" }" | out-file $shim -encoding oem -append
    echo 'if($env:home -eq "\") { $env:home = $env:allusersprofile }' | out-file $shim -encoding oem -append
    echo "`$path = `"$path`"" | out-file $shim -encoding oem -append
    if($arg) {
        echo "`$args = '$($arg -join "', '")', `$args" | out-file $shim -encoding oem -append
    }
    echo 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' | out-file $shim -encoding oem -append

    if($path -match '\.exe$') {
        # for programs with no awareness of any shell
        $shim_exe = "$(strip_ext($shim)).shim"
        cp "$(versiondir 'scoop' 'current')\supporting\shimexe\shim.exe" "$(strip_ext($shim)).exe" -force
        echo "path = $(resolve-path $path)" | out-file $shim_exe -encoding oem
        if($arg) {
            echo "args = $arg" | out-file $shim_exe -encoding oem -append
        }
    } elseif($path -match '\.((bat)|(cmd))$') {
        # shim .bat, .cmd so they can be used by programs with no awareness of PSH
        # NOTE: this code transfers execution flow via hand-off, not a call, so any modifications if/while in-progress are safe
        $shim_cmd = "$(strip_ext($shim)).cmd"
        ':: ensure $HOME is set for MSYS programs'           | out-file $shim_cmd -encoding oem
        '@if "%home%"=="" set home=%homedrive%%homepath%\'   | out-file $shim_cmd -encoding oem -append
        '@if "%home%"=="\" set home=%allusersprofile%\'      | out-file $shim_cmd -encoding oem -append
        "@`"$(resolve-path $path)`" $arg %*"                 | out-file $shim_cmd -encoding oem -append
    } elseif($path -match '\.ps1$') {
        # make ps1 accessible from cmd.exe
        $shim_cmd = "$(strip_ext($shim)).cmd"
        # default code; NOTE: only scoop knows about and manipulates shims so, by default, no special care is needed for other apps
        $code = "@powershell -noprofile -ex unrestricted `"& '$(resolve-path $path)' $arg %* ; exit `$lastexitcode`""
        if ($name -eq 'scoop') {
            # shimming self; specialized code is required
            $code = shim_scoop_cmd_code $shim_cmd $path $arg
        }
        $code | out-file $shim_cmd -encoding oem
    }
}

function shim_scoop_cmd_code($shim_cmd_path, $path, $arg) {
    # specialized code for the scoop CMD shim
    # * special handling is needed for in-progress updates
    # * additional code needed to pipe environment variables back up and into to the original calling CMD process (see shim_scoop_cmd_code_body())

    $CMD_shim_fullpath = resolve-path $shim_cmd_path
    $CMD_shim_content = Get-Content $CMD_shim_fullpath

    # prefix code ## handle in-progress updating
    # updating an in-progress BAT/CMD must be done with precise pre-planning to avoid unanticipated execution paths (and associated possible errors)
    # NOTE: must assume that the scoop CMD shim may be currently executing (since there is no simple way to determine that condition)

    # NOTE: current scoop CMD shim is in one of two states:
    # 1. update-naive (older) version which calls scoop.ps1 via powershell as the last statement
    #    - control flow returns to the script, executing from the character position just after the call statement
    #    - notably, the position is determined *when the call was initially made in the original source* ignoring any script changes
    # 2. update-enabled version (by using either an exiting line/block or proxy execution) which can be modified without limitation

    $safe_update_signal_text = '*(scoop:#update-enabled)' # "magic" signal string ## the presence of this signal within a shim indicates that it is designed to allow in-progress updates with safety

    $code = "@::$safe_update_signal_text`r`n"

    if (-not ($CMD_shim_content -cmatch [regex]::Escape($safe_update_signal_text))) {
        # current shim is update-naive
        $code += '@goto :__START__' + "`r`n"  # embed code for correct future executions; jumps past any buffer segment
        # buffer the prefix with specifically designed & sized code for safe return/completion of current execution
        $buffer_text = ''
        $CMD_shim_original_size = (Get-ChildItem $CMD_shim_fullpath).length
        $size_diff = $CMD_shim_original_size - $code.length
        if ($size_diff -lt 0) {
            # errors may occur upon exiting, ask user for re-run to help normalize the situation
            warn 'scoop encountered an update inconsistency, please re-run "scoop update"'
        }
        elseif ( $size_diff -gt 0 ) {
            # note: '@' characters, acting as NoOPs, are used to reduce the risk of wrong command execution in the case that we've miscalculated the return/continue location of the execution pointer
            if ( $size_diff -eq 1 ) { $buffer_text = '@' <# no room for EOL CRLF #>}
            else { $buffer_text = $('@' * ($size_diff-2)) + "`r`n" }
        }
        $code += $buffer_text + '@goto :EOF &:: safely end a returning, and now modified, in-progress script' + "`r`n"
        $code += '@:__START__' + "`r`n"
    }

    # body code ## handles update-enabled scoop call and the environment variable pipe
    $code += shim_scoop_cmd_code_body $(resolve-path $path) $arg

    $code
}

function shim_scoop_cmd_code_body($path, $arg) {
# shim startup / initialization code
$code = '
@set "ERRORLEVEL="
@setlocal
@echo off
set __ME=%~n0

:: NOTE: flow of control is passed (with *no return*) from this script to a proxy BAT/CMD script; any modification of this script is safe at any execution time after that control hand-off

:: require temporary files
:: * (needed for both out-of-source proxy contruction and for piping in-process environment variable updates)
call :_tempfile __oosource "%__ME%.oosource" ".bat"
if NOT DEFINED __oosource ( goto :TEMPFILE_ERROR )
call :_tempfile __pipe "%__ME%.pipe" ".bat"
if NOT DEFINED __pipe ( goto :TEMPFILE_ERROR )
goto :TEMPFILES_FOUND
:TEMPFILES_ERROR
echo %__ME%: ERROR: unable to open needed temporary file(s) [make sure to set TEMP or TMP to an available writable temporary directory {try "set TEMP=%%LOCALAPPDATA%%\Temp"}] 1>&2
exit /b -1
:TEMPFILES_FOUND
'
# shim code initializing environment pipe
$code += '
@::* initialize environment pipe
echo @:: TEMPORARY source/exec environment pipe [owner: "%~f0"] > "%__pipe%"
'
# shim code initializing proxy
$code += '
@::* initialize out-of-source proxy and add proxy initialization code
echo @:: TEMPORARY out-of-source executable proxy [owner: "%~f0"] > "%__oosource%"
echo (set ERRORLEVEL=) >> "%__oosource%"
echo setlocal >> "%__oosource%"
'
# shim code adding scoop call to proxy
$code += "
@::* out-of-source proxy code to call scoop
echo call powershell -NoProfile -ExecutionPolicy unrestricted -Command ^`"^& '$path' -__CMDenvpipe '%__pipe%' $arg %*^`" >> `"%__oosource%`"
"
# shim code adding piping of environment changes and cleanup/exit to proxy
$code += '
@::* out-of-source proxy code to source environment changes and cleanup
echo (set __exit_code=%%ERRORLEVEL%%) >> "%__oosource%"
echo ^( endlocal >> "%__oosource%"
echo call ^"%__pipe%^"  >> "%__oosource%"
echo call erase /q ^"%__pipe%^" ^>NUL 2^>NUL >> "%__oosource%"
echo start ^"^" /b cmd /c del ^"%%~f0^" ^& exit /b %%__exit_code%% >> "%__oosource%"
echo ^) >> "%__oosource%"
'
# shim code to hand-off execution to the proxy (makes this shim "update-enabled")
$code += '
endlocal & "%__oosource%" &:: hand-off to proxy; intentional non-call (no return from proxy) to allow for safe updates of this script
'
# shim script subroutines
$code += '
goto :EOF
::#### SUBs

::
:_tempfile ( ref_RETURN [PREFIX [EXTENSION]])
:: open a unique temporary file
:: RETURN == full pathname of temporary file (with given PREFIX and EXTENSION) [NOTE: has NO surrounding quotes]
:: PREFIX == optional filename prefix for temporary file
:: EXTENSION == optional extension (including leading ".") for temporary file [default == ".bat"]
setlocal
set "_RETval="
set "_RETvar=%~1"
set "prefix=%~2"
set "extension=%~3"
if NOT DEFINED extension ( set "extension=.bat")
:: find a temp directory (respect prior setup; default to creating/using "%LocalAppData%\Temp" as a last resort)
if NOT EXIST "%temp%" ( set "temp=%tmp%" )
if NOT EXIST "%temp%" ( mkdir "%LocalAppData%\Temp" 2>NUL & cd . & set "temp=%LocalAppData%\Temp" )
if NOT EXIST "%temp%" ( goto :_tempfile_RETURN )    &:: undefined TEMP, RETURN (with NULL result)
:: NOTE: this find unique/instantiate loop has an unavoidable race condition (but, as currently coded, the real risk of collision is virtually nil)
:_tempfile_find_unique_temp
set "_RETval=%temp%\%prefix%.%RANDOM%.%RANDOM%%extension%" &:: arbitrarily lower risk can be obtained by increasing the number of %RANDOM% entries in the file name
if EXIST "%_RETval%" ( goto :_tempfile_find_unique_temp )
:: instantiate tempfile
set /p OUTPUT=<nul >"%_RETval%"
:_tempfile_find_unique_temp_DONE
:_tempfile_RETURN
endlocal & set %_RETvar%^=%_RETval%
goto :EOF
::

goto :EOF
'
$code
}

function ensure_in_path($dir, $global) {
    $path = env 'path' -t $global
    $dir = fullpath $dir
    if($path -notmatch [regex]::escape($dir)) {
        echo "adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path"

        env 'path' -t $global "$dir;$path" # for future sessions...
        env 'path' "$dir;$env:path"        # for this session
    }
}

function strip_path($orig_path, $dir) {
    $stripped = [string]::join(';', @( $orig_path.split(';') | ? { $_ -and $_ -ne $dir } ))
    return ($stripped -ne $orig_path), $stripped
}

function remove_from_path($dir,$global) {
    $dir = fullpath $dir

    # future sessions
    $was_in_path, $newpath = strip_path (env 'path' -t $global) $dir
    if($was_in_path) {
        echo "removing $(friendly_path $dir) from your path"
        env 'path' -t $global $newpath
    }

    # current session
    $was_in_path, $newpath = strip_path $env:path $dir
    if($was_in_path) { env 'path' $newpath }
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
            write-host "alias $name is read-only; can't reset it" -f darkyellow
        }
        return # already set
    }
    if($value -is [scriptblock]) {
        new-item -path function: -name "script:$name" -value $value | out-null
        return
    }

    set-alias $name $value -scope script -option allscope
}

function reset_aliases() {
    # for aliases where there's a local function, re-alias so the function takes precedence
    $aliases = get-alias |? { $_.options -notmatch 'readonly' } |% { $_.name }
    get-childitem function: | % {
        $fn = $_.name
        if($aliases -contains $fn) {
            set-alias $fn local:$fn -scope script
        }
    }

    # set default aliases
    $default_aliases.keys | % { reset_alias $_ $default_aliases[$_] }
}

function CMD_SET_encode_arg {
    # CMD_SET_encode_arg( @ )
    # encode string(s) to equivalent CMD command line interpretable version(s) as arguments for SET
    if ($args -ne $null) {
        $args | ForEach-Object {
            $val = $_
            $val = $($val -replace '\^','^^')
            $val = $($val -replace '\(','^(')
            $val = $($val -replace '\)','^)')
            $val = $($val -replace '<','^<')
            $val = $($val -replace '>','^>')
            $val = $($val -replace '\|','^|')
            $val = $($val -replace '&','^&')
            $val = $($val -replace '"','^"')
            $val = $($val -replace '%','^%')
            $val
            }
        }
    }
