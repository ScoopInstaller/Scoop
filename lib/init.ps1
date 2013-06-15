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
function ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
function friendly_path($path) {
  return "$path" -replace ([regex]::escape($home)), "~"
}
function installed($name) { return test-path (appdir $name) }
function assert_not_installed($name) {
  if(installed $name) { abort("$name is already installed.") }
}
function unzip($path,$to) {
    $shell = (new-object -com shell.application)
    $zipfiles = $shell.namespace("$path").items()
    $shell.namespace("$to").copyHere($zipFiles, 4) # 4 = don't show progress dialog
}

function stub($path) {
  if(!(test-path $path)) { abort "can't stub $(fname $path): couldn't find $path"}
  $abs_bindir = ensure $bindir
  $stub = "$abs_bindir\$(fname $path)"

  echo "`$rawargs = `$myInvocation.line -replace `"^`$([regex]::escape(`$myInvocation.invocationName))\s+`", `"`"" >> "$stub"
  echo "iex `"$path `$rawargs`"" >> "$stub"
}

function ensure_scoop_in_path { 
  $userpath = env 'path'
  $abs_bindir = ensure $bindir
  if($userpath -notmatch [regex]::escape($abs_bindir)) {
      # be aggressive (b-e-aggressive) and install scoop first in the path
      echo "adding $(friendly_path $abs_bindir) to your user path"
      env 'path' "$abs_bindir;$userpath"  # for future sessions
      $env:path = "$abs_bindir;$env:path" # for this session
  }
}