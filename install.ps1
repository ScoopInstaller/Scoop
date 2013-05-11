# options
$branch = 'dev' # use this git branch of cscript (dev or master)

# setup
$erroractionpreference='stop' # for try-catch to work

# helpers
function err($msg) { write-host $msg -b darkred -f white; exit 1 }
function getenv($name) { [environment]::GetEnvironmentVariable($name, 'User') }
function setenv($name, $val) { [Environment]::SetEnvironmentVariable($name, $val, 'User') }

$bindir = "$env:localappdata\bin"
if(-not (test-path $bindir)) { echo "creating $bindir"; mkdir $bindir > $null }

$srcdir = "$bindir\scriptcs"
if(test-path $srcdir) { err "scriptcs is already installed!" }

# ensure git is useable
try { gcm git > $null } catch { err "failed: couldn't find git!" }

# clone git repo
& git clone -b $branch https://github.com/scriptcs/scriptcs.git "$srcdir"

# build
pushd $srcdir
try { & .\build.cmd } finally { popd }

# create bin stubs
$exe = "$srcdir\src\ScriptCs\bin\Debug\scriptcs.exe"
echo "& ""$exe"" `$args" >> "$bindir\scriptcs.ps1"

# ensure ~\appdata\local\bin in user's path
if((getenv 'path') -notmatch [regex]::escape($bindir)) {
  echo "adding $bindir to your path"
  setenv "path" "$env:path;$bindir"
}

write-host "done! type scriptcs to run" -b darkgreen -f white