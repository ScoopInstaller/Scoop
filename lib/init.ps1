$scoopdir = "~\appdata\local\scoop"
$bindir = "$scoopdir\bin"

# helper functions
function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
function env($name,$val) {
  if($val) { [environment]::setEnvironmentVariable($name,$val,'User') } # set
  else { [environment]::getEnvironmentVariable($name, 'User') } # get
}
function abort($msg) { write-host $msg -b darkred -f white; exit 1 }
function success($msg) { write-host $msg -b darkgreen -f white; }
function appdir($name, $version) { "$scoopdir\$name\$version" }
function fname($path) { split-path $path -leaf }
function ensure($dir) { if(!(test-path $dir)) { mkdir $dir > $null }; resolve-path $dir }
function stub($path) {
  $abs_bindir = ensure $bindir
  $stub = "$absbindir\$(fname $path).ps1"

  echo "`$rawargs = `$myInvocation.line -replace `"^`$([regex]::escape(`$myInvocation.invocationName))\s+`", `"`"" >> "$stub"
  echo "iex `"$path `$rawargs`"" >> "$stub"
}
function friendly_path($path) {
  $home = "$(resolve-path "~")"
  return "$path" -replace ([regex]::escape($home)), "~"
}
function ensure_scoop_in_path { 
  $userpath = env 'path'
  $abs_bindir = ensure $bindir
  if($userpath -notmatch [regex]::escape($abs_bindir)) {
      # be aggressive and install scoop first in the path
      echo "adding $(friendly_path $absbindir) to your user path"
      env 'path' "$abs_bindir;$userpath"  # for future sessions
      $env:path = "$abs_bindir;$env:path" # for this session
  }
}
function installed($name, $version) { return test-path (appdir $name $version) }
function assert_not_installed($name, $version) {
  if(installed $name $version) {
    abort("``$name`` ($version) is already installed.") }
  }
}
function unzip($path,$to) {
    $shell = (new-object -com shell.application)
    $zipfiles = $shell.namespace($path).items()
    $shell.namespace($to).copyHere($zipFiles, 4) # 4 = don't show progress dialog
}