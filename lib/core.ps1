$scoopdir = "~\appdata\local\scoop"
$bindir = "$scoopdir\bin"

# helper functions
function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
function env($name,$val) {
	if($val) { [environment]::setEnvironmentVariable($name,$val,'User') } # set
	else { [environment]::getEnvironmentVariable($name, 'User') } # get
}
function abort($msg) { write-host $msg -b darkred -f white; exit 1 }
function success($msg) { write-host $msg -b green -f black; }
function appdir($name) { "$scoopdir\apps\$name" }

function fname($path) { split-path $path -leaf }
function strip_ext($fname) { $fname -replace '\.[^\.]*$', '' }

function ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
function full_path($path) { # should be ~ rooted
	$executionContext.sessionState.path.getUnresolvedProviderPathFromPSPath($path)
}
function friendly_path($path) {
	return "$path" -replace ([regex]::escape($home)), "~"
}
function resolve($path) { "$($myInvocation.PSScriptRoot)\$path" } # relative to calling script

function installed($name) { return test-path (appdir $name) }
function unzip($path,$to) {
	if(!(test-path $path)) { abort "can't find $path to unzip"}
	$shell = (new-object -com shell.application)
	$zipfiles = $shell.namespace("$path").items()
	$shell.namespace("$to").copyHere($zipFiles, 4) # 4 = don't show progress dialog
}
function coalesce($a, $b) { if($a) { return $a } $b }
function format($str, $hash) {
	$hash.keys | % { set-variable $_ $hash[$_] }
	$executionContext.invokeCommand.expandString($str)
}

function stub($path) {
	if(!(test-path $path)) { abort "can't stub $(fname $path): couldn't find $path" }
	$abs_bindir = ensure $bindir
	$stub = "$abs_bindir\$(strip_ext(fname $path)).ps1"

	echo "`$rawargs = `$myInvocation.line -replace `"^`$([regex]::escape(`$myInvocation.invocationName))\s+`", `"`"" >> "$stub"
	echo "iex `"$path `$rawargs`"" >> "$stub"
}
function ensure_scoop_in_path { 
	$userpath = env 'path'
	$abs_bindir = ensure $bindir
	if($userpath -notmatch [regex]::escape($abs_bindir)) {
		# be aggressive (b-e-aggressive) and install scoop first in the path
		echo "adding $(friendly_path $abs_bindir) to your path"
		env 'path' "$abs_bindir;$userpath"  # for future sessions
		$env:path = "$abs_bindir;$env:path" # for this session
	}
}