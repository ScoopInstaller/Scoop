$scoopdir = "~\appdata\local\scoop"
$bindir = "$scoopdir\bin"

# helper functions
function coalesce($a, $b) { if($a) { return $a } $b }
function format($str, $hash) {
	$hash.keys | % { set-variable $_ $hash[$_] }
	$executionContext.invokeCommand.expandString($str)
}

# messages
function abort($msg) { write-host $msg -b darkred -f white; exit 1 }
function warn($msg) { write-host $msg -f yellow; }
function success($msg) { write-host $msg -b green -f black; }

# apps
function appdir($app) { "$scoopdir\apps\$app" }
function versiondir($app, $version) { "$(appdir $app)\$version" }
function installed($app) { return test-path (appdir $app) }

# paths
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

function stub($path) {
	if(!(test-path $path)) { abort "can't stub $(fname $path): couldn't find $path" }
	$abs_bindir = ensure $bindir
	$stub = "$abs_bindir\$(strip_ext(fname $path).tolower()).ps1"

	# note: use > for first line to replace, then >> to append following lines
	echo ". ""$(versiondir 'scoop' 'current')\lib\core.ps1""" > $stub
	echo "`$path = '$path'" >> $stub
	echo 'if($myinvocation.expectingInput) { $input | & $path @args } else { & $path @args }' >> $stub
}

<#
# re-parses to get the raw command for this invocation (minus pipes, other expressions etc.)
function command($inv) {
	$cmdName = $inv.InvocationName
	$ast = [System.Management.Automation.Language.Parser]::ParseInput($inv.line, [ref]$null, [ref]$null)

	$cmd = $ast.find({
		($args[0].gettype().name -eq 'commandast') -and	(
			($cmdName -eq '&' -and $args[0].invocationoperator -eq 'Ampersand') -or
			($args[0].getcommandname() -eq $cmdName)
		)
	}, $true)

	$cmd.extent.text
}

function rawargs($inv) {
	(command $inv) -replace "^\s*(&?\s*)?(('[^']*')|([^\s]*))\s*", ""
}

function exec_stub($path, $inv) {
	iex "&'$path' $(rawargs $inv)"
}#>

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