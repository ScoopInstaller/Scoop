$scoopdir = "~\appdata\local\scoop"
$shimdir  = "$scoopdir\shims"
$cachedir = "$scoopdir\cache"

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }
function format($str, $hash) {
	$hash.keys | % { set-variable $_ $hash[$_] }
	$executionContext.invokeCommand.expandString($str)
}

# messages
function abort($msg) { write-host $msg -f darkred; exit 1 }
function warn($msg) { write-host $msg -f darkyellow; }
function success($msg) { write-host $msg -f darkgreen }

# apps
function appdir($app) { "$scoopdir\apps\$app" }
function versiondir($app, $version) { "$(appdir $app)\$version" }
function installed($app) { return test-path (appdir $app) }
function installed_apps {
	if(test-path "$scoopdir\apps") {
		gci ( "$scoopdir\apps") | where { $_.psiscontainer -and $_.name -ne 'scoop' } | % { $_.name }
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
	return "$path" -replace ([regex]::escape($home)), "~"
}
function is_local($path) {
	($path -notmatch '^https?://') -and (test-path $path)
}

# operations
function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
function env($name,$val) {
	if($val) { [environment]::setEnvironmentVariable($name,$val,'User') } # set
	else { [environment]::getEnvironmentVariable($name, 'User') } # get
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

function shim($path) {
	if(!(test-path $path)) { abort "can't shim $(fname $path): couldn't find $path" }
	$abs_shimdir = ensure $shimdir
	$shim = "$abs_shimdir\$(strip_ext(fname $path).tolower()).ps1"

	# note: use > for first line to replace, then >> to append following lines
	echo "`$path = '$path'" > $shim
	echo 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' >> $shim

	$shim_cmd = "$(strip_ext($shim)).cmd"
	"@`"$path`" %*" | out-file $shim_cmd -encoding oem
}

function ensure_in_path($dir,$first=$false) {
	$userpath = env 'path'
	$dir = fullpath $dir
	if($userpath -notmatch [regex]::escape($dir)) {
		echo "adding $(friendly_path $dir) to your path"
		
		# for future sessions...
		if($first) { env 'path' "$dir;$userpath" }
		else { env 'path' "$userpath;$dir"	}

		# for this session
		if($first) { $env:path = "$dir;$env:path" }
		else { $env:path = "$env:path;$dir" }
	}
}

function strip_path($orig_path, $dir) {
	$stripped = [string]::join(';', @( $orig_path.split(';') | ? { $_ -and $_ -ne $dir } ))
	return ($stripped -ne $orig_path), $stripped
}

function remove_from_path($dir) {
	$dir = fullpath $dir

	# future sessions
	$was_in_path, $newpath = strip_path (env 'path') $dir
	if($was_in_path) { 
		echo "removing $(friendly_path $dir) from your path"
		env 'path' $newpath
	}

	# current session
	$was_in_path, $newpath = strip_path $env:path $dir
	if($was_in_path) { $env:path = $newpath	}
}

function ensure_scoop_in_path {
	$abs_shimdir = ensure $shimdir
	# be aggressive (b-e-aggressive) and install scoop first in the path
	ensure_in_path $abs_shimdir $true
}