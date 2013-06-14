# 1. installs a powershell script to ~\appdata\local\scoop\[name]\[name].ps1
# 2. adds a stub to ~\appdata\local\scoop\bin, to avoid path pollution
# 3. makes sure ~\appdata\local\scoop\bin is in your path
function install-ps($name, $url) {
    $erroractionpreference = 'stop'
    
    # helpers
    function dl($url,$to) { (new-object system.net.webClient).downloadFile($url,$to) }
    function env($name,$val) {
        if($val) { [environment]::setEnvironmentVariable($name,$val,'User') } # set
        else { [environment]::getEnvironmentVariable($name, 'User') } # get
    }
    function abort($msg) { write-host $msg -b darkred -f white; exit 1 }
    
    # prep
    echo "installing $name..."
    if($name.endswith(".ps1")) { $name = $name -replace '\.ps1$', '' }
    
    $scoopdir = "~\appdata\local\scoop"
    $bindir = "$scoopdir\bin"
    $appdir = "$scoopdir\$name"
    
    if(test-path $appdir) { abort("It looks like ``$name`` is already installed. If you'd like to re-install, please run ``rmdir ~\appdata\local\scoop\$name`` first.") }
    
    # install
    mkdir $appdir > $null
    $appdir = resolve-path $appdir
    echo "downloading $url..."
    dl $url "$appdir\$name.ps1"
    
    # binstub
    echo "creating stub in ~\appdata\local\bin"
    if(!(test-path $bindir)) { mkdir $bindir > $null }
    $bindir = resolve-path $bindir
    
    echo "`$rawargs = `$myInvocation.line -replace `"^`$([regex]::escape(`$myInvocation.invocationName))\s+`", `"`"" >> "$bindir\$name.ps1"
    echo "iex `"$appdir\$name.ps1 `$rawargs`"" >> "$bindir\$name.ps1"
    
    # ensure path
    $userpath = env 'path'
    if($userpath -notmatch [regex]::escape($bindir)) {
        echo "adding ~\appdata\local\bin to your user path"
        env 'path' "$userpath;$bindir"  # for future sessions
        $env:path = "$env:path;$bindir" # for this session
    }
    
    echo "done!"
}