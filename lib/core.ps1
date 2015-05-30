$scoopdir = $env:SCOOP, "~\appdata\local\scoop" | select -first 1
$globaldir = $env:SCOOP_GLOBAL, "$($env:programdata.tolower())\scoop" | select -first 1
$cachedir = "$scoopdir\cache" # always local

# using functions as aliases for powershell commands
function script:cp() { copy-item @args } 
function script:echo() { write-output @args } 
function script:gc() { get-content @args } 
function script:gci() { get-childitem @args } 
function script:gcm() { get-command @args } 
function script:iex() { invoke-expression @args } 
function script:ls() { get-childitem @args } 
function script:mkdir() { new-item -type directory @args } 
function script:mv() { move-item @args } 
function script:rm() { remove-item @args } 
function script:rmdir() { remove-item @args } 
function script:sc() { set-content @args } 
function script:select() { select-object @args } 
function script:sls() { select-string @args } 

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }
function scoop_format($str, $hash) {
	$hash.keys | % { set-variable $_ $hash[$_] }
	$executionContext.invokeCommand.expandString($str)
}
set-alias format scoop_format

function is_admin {
	$admin = [security.principal.windowsbuiltinrole]::administrator
	$id = [security.principal.windowsidentity]::getcurrent()
	([security.principal.windowsprincipal]($id)).isinrole($admin)
}

# messages
function message_abort($msg) { write-host $msg -f darkred; exit 1 }
set-alias abort message_abort
function message_warn($msg) { write-host $msg -f darkyellow; }
set-alias warn message_warn
function message_success($msg) { write-host $msg -f darkgreen }
set-alias success message_success

# dirs
function basedir($global) {	if($global) { return $globaldir } $scoopdir }
function appsdir($global) { "$(basedir $global)\apps" }
function shimdir($global) { "$(basedir $global)\shims" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }

# apps
function scoop_installed($app, $global=$null) {
	if($global -eq $null) { return (installed $app $true) -or (installed $app $false) }
	return test-path (appdir $app $global)
}
set-alias installed scoop_installed

function installed_apps($global) {
	$dir = appsdir $global
	if(test-path $dir) {
		gci $dir | where { $_.psiscontainer -and $_.name -ne 'scoop' } | % { $_.name }
	}
}

# paths
function scoop_fname($path) { split-path $path -leaf }
set-alias fname scoop_fname
function strip_ext($fname) { $fname -replace '\.[^\.]*$', '' }

function scoop_ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
set-alias ensure scoop_ensure
function scoop_fullpath($path) { # should be ~ rooted
	$executionContext.sessionState.path.getUnresolvedProviderPathFromPSPath($path)
}
set-alias fullpath scoop_fullpath
function scoop_relpath($path) { "$($myinvocation.psscriptroot)\$path" } # relative to calling script
set-alias relpath scoop_relpath
function friendly_path($path) {
	$h = $home; if(!$h.endswith('\')) { $h += '\' }
	return "$path" -replace ([regex]::escape($h)), "~\"
}
function is_local($path) {
	($path -notmatch '^https?://') -and (test-path $path)
}

# operations
function scoop_download($url,$to) {
	$wc = new-object system.net.webClient
	$wc.headers.add('User-Agent', 'Scoop/1.0')
	$wc.downloadFile($url,$to)

}
set-alias dl scoop_download

function scoop_env($name,$global,$val='__get') {
	$target = 'User'; if($global) {$target = 'Machine'}
	if($val -eq '__get') { [environment]::getEnvironmentVariable($name,$target) }
	else { [environment]::setEnvironmentVariable($name,$val,$target) }
}
set-alias env scoop_env

function scoop_unzip($path,$to) {
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
set-alias unzip scoop_unzip

function unzip_old($path,$to) {
	# fallback for .net earlier than 4.5
	$shell = (new-object -com shell.application -strict)
	$zipfiles = $shell.namespace("$path").items()
	$to = ensure $to
	$shell.namespace("$to").copyHere($zipfiles, 4) # 4 = don't show progress dialog
}

function scoop_movedir($from, $to) {
	$from = $from.trimend('\')
	$to = $to.trimend('\')

	$out = robocopy "$from" "$to" /e /move
	if($lastexitcode -ge 8) {
		throw "error moving directory: `n$out"
	}
}
set-alias movedir scoop_movedir

function scoop_shim($path, $global, $name, $arg) {
	if(!(test-path $path)) { abort "can't shim $(fname $path): couldn't find $path" }
	$abs_shimdir = ensure (shimdir $global)
	if(!$name) { $name = strip_ext (fname $path) }

	$shim = "$abs_shimdir\$($name.tolower()).ps1"

	# note: use > for first line to replace file, then >> to append following lines
	echo '# ensure $HOME is set for MSYS programs' > $shim
	echo "if(!`$env:home) { `$env:home = `"`$home\`" }" >> $shim
	echo 'if($env:home -eq "\") { $env:home = $env:allusersprofile }' >> $shim
	echo "`$path = `"$path`"" >> $shim
	if($arg) {
		echo "`$args = '$($arg -join "', '")', `$args" >> $shim
	}
	echo 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' >> $shim

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
		$shim_cmd = "$(strip_ext($shim)).cmd"
		':: ensure $HOME is set for MSYS programs'           | out-file $shim_cmd -encoding oem
		'@if "%home%"=="" set home=%homedrive%%homepath%\'   | out-file $shim_cmd -encoding oem -append
		'@if "%home%"=="\" set home=%allusersprofile%\'      | out-file $shim_cmd -encoding oem -append
		"@`"$(resolve-path $path)`" $arg %*"                 | out-file $shim_cmd -encoding oem -append
	} elseif($path -match '\.ps1$') {
		# make ps1 accessible from cmd.exe
		$shim_cmd = "$(strip_ext($shim)).cmd"
		"@powershell -noprofile -ex unrestricted `"& '$(resolve-path $path)' %*;exit `$lastexitcode`"" | out-file $shim_cmd -encoding oem
	}
}
set-alias shim scoop_shim

function ensure_in_path($dir, $global) {
	$path = env 'path' $global
	$dir = fullpath $dir
	if($path -notmatch [regex]::escape($dir)) {
		echo "adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) path"
		
		env 'path' $global "$dir;$path" # for future sessions...
		$env:path = "$dir;$env:path" # for this session
	}
}

function strip_path($orig_path, $dir) {
	$stripped = [string]::join(';', @( $orig_path.split(';') | ? { $_ -and $_ -ne $dir } ))
	return ($stripped -ne $orig_path), $stripped
}

function remove_from_path($dir,$global) {
	$dir = fullpath $dir

	# future sessions
	$was_in_path, $newpath = strip_path (env 'path' $global) $dir
	if($was_in_path) { 
		echo "removing $(friendly_path $dir) from your path"
		env 'path' $global $newpath
	}

	# current session
	$was_in_path, $newpath = strip_path $env:path $dir
	if($was_in_path) { $env:path = $newpath	}
}

function ensure_scoop_in_path($global) {
	$abs_shimdir = ensure (shimdir $global)
	# be aggressive (b-e-aggressive) and install scoop first in the path
	ensure_in_path $abs_shimdir $global
}

function scoop_wraptext($text, $width) {
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
set-alias wraptext scoop_wraptext

function scoop_pluralize($count, $singular, $plural) {
	if($count -eq 1) { $singular } else { $plural }
}
set-alias pluralize scoop_pluralize