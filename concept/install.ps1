# options
$branch = 'dev' # use this git branch of cscript (dev or master)

# setup
$erroractionpreference='stop' # for try-catch to work

# helpers
function abort($msg) { write-host $msg -b darkred -f white; exit 1 }
function getenv($name) { [environment]::getEnvironmentVariable($name, 'User') }
function setenv($name,$val) { [environment]::setEnvironmentVariable($name,$val,'User') }
function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
function unzip($path,$to) {
    $shell = (new-object -com shell.application)
    $zipfiles = $shell.namespace($path).items()
    $shell.namespace($to).copyHere($zipFiles, 4) # 4 = don't show progress dialog
}

$bindir = "$env:localappdata\bin"
if(-not (test-path $bindir)) { echo "creating $bindir"; mkdir $bindir > $null }

$scoopdir = "$env:localappdata\scoop"
$srcdir = "$scoopdir\scriptcs\$branch"
if(test-path $srcdir) { abort "scriptcs is already installed!" }
mkdir $srcdir > $null

# check for, download roslyn

# download scriptcs
echo "downloading scriptcs $branch source..."
dl "https://github.com/scriptcs/scriptcs/archive/$branch.zip" "$srcdir\dl.zip"
echo "extracting source..."
unzip "$srcdir\dl.zip" "$srcdir"
rm "$srcdir\dl.zip"
exit

# check for, download .net 4

# build scriptcs

# create bin stubs
$exe = "$srcdir\scriptcs-$branch\src\scriptcs\bin\debug\scriptcs.exe"
echo "& ""$exe"" `$args" >> "$bindir\scriptcs.ps1"

# ensure ~\appdata\local\bin in user's path
if((getenv 'path') -notmatch [regex]::escape($bindir)) {
  echo "adding $bindir to your path"
  setenv "path" "$env:path;$bindir"
}

write-host "done! restart your shell and type scriptcs to run" -b darkgreen -f white