# remote install:
#   iex (new-object net.webclient).downloadstring('https://raw.github.com/lukesampson/scoop/master/install.ps1')
# local install (for dev testing onyl):
#   .\install -local
param([switch]$local)
$erroractionpreference='stop' # quit if anything goes wrong

# get core functions
if($local) {
    echo "will install from local files"
    . "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"
} else {
    $core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
    echo 'initializing...'
    iex (new-object net.webclient).downloadstring($core_url)
}

# prep
if(installed 'scoop') {
    abort "scoop is already installed. run 'scoop update' to get the latest version."
}
$dir = ensure (versiondir 'scoop' 'current')
echo $dir


if($local) {
    'copying files...'
    $mimicdir = ensure "$dir\scoop-master" # scoop-master mimics the remote install
    cp .\* $mimicdir -recurse 
} else { # download scoop zip
    $zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
    $zipfile = "$dir\scoop.zip"
    echo 'downloading...'
    dl $zipurl $zipfile

    'extracting...'
    unzip $zipfile $dir
    rm $zipfile
}

echo 'creating stub...'
stub "$dir\scoop-master\bin\scoop.ps1"

ensure_scoop_in_path
success 'scoop was installed successfully!'
echo 'type "scoop help" for instructions'
