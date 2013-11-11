$scoopdir = "~\appdata\local\scoop"
$globaldir = "$($env:programdata.tolower())\scoop"
$cachedir = "$scoopdir\cache" # always local

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
function basedir($global) {	if($global) { return $globaldir } $scoopdir }
function appsdir($global) { "$(basedir $global)\apps" }
function shimdir($global) { "$(basedir $global)\shims" }
function appdir($app, $global) { "$(appsdir $global)\$app" }
function versiondir($app, $version, $global) { "$(appdir $app $global)\$version" }

# apps
function installed($app, $global) { return test-path (appdir $app $global) }
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
function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
function env($name,$global,$val='__get') {
	$target = 'User'; if($global) {$target = 'Machine'}
	if($val -eq '__get') { [environment]::getEnvironmentVariable($name,$target) }
	else { [environment]::setEnvironmentVariable($name,$val,$target) }
}
function unzip($path,$to,$folder) {
	if(!(test-path $path)) { abort "can't find $path to unzip"}
	$shell = (new-object -com shell.application -strict)
	$zipfiles = $shell.namespace("$path").items()
	
	if($folder) { # note: couldn't get this to work as a separate function
		$next, $rem = $folder.split('\')
		while($next) {
			$found = $false
			foreach($item in $zipfiles) {
				if($item.isfolder -and ($item.name -eq $next)) {
					$zipfiles = $item.getfolder.items()
					$found = $true
					break
				}
			}
			if(!$found) { abort "couldn't find folder '$folder' inside $(friendly_path $path)" }
			$next, $rem = $rem
		}
	}

	$shell.namespace("$to").copyHere($zipfiles, 4) # 4 = don't show progress dialog
}

function shim($path, $global) {
	if(!(test-path $path)) { abort "can't shim $(fname $path): couldn't find $path" }
	$abs_shimdir = ensure (shimdir $global)
	$shim = "$abs_shimdir\$(strip_ext(fname $path).tolower()).ps1"

	# note: use > for first line to replace file, then >> to append following lines
	echo '# ensure $HOME is set for MSYS programs' > $shim
	echo "if(!`$env:home) { `$env:home = `"`$home\`" }" >> $shim
	echo 'if($env:home -eq "\") { $env:home = $env:allusersprofile }' >> $shim
	echo "`$path = '$path'" >> $shim
	echo 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' >> $shim

	if($path -match '\.((exe)|(bat)|(cmd))$') {
		# shim .exe, .bat, .cmd so they can be used by programs with no awareness of PSH
		$shim_cmd = "$(strip_ext($shim)).cmd"
		':: ensure $HOME is set for MSYS programs'           | out-file $shim_cmd -encoding oem
		'@if "%home%"=="" set home=%homedrive%%homepath%\'   | out-file $shim_cmd -encoding oem -append
		'@if "%home%"=="\" set home=%allusersprofile%\'      | out-file $shim_cmd -encoding oem -append
		"@`"$path`" %*"                                      | out-file $shim_cmd -encoding oem -append
	} elseif($path -match '\.ps1$') {
		# make ps1 accessible from cmd.exe
		$shim_cmd = "$(strip_ext($shim)).cmd"
		"@powershell -noprofile -ex unrestricted `"& '$path' %*;exit `$lastexitcode`"" | out-file $shim_cmd -encoding oem
	}
}

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