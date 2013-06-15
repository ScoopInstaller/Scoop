# install with:
#   iex (new-object net.webclient).downloadstring('https://raw.github.com/lukesampson/scoop/master/install.ps1')
$erroractionpreference='stop' # quit if anything goes wrong

# get core functions
$core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
echo 'initializing...'
iex (new-object net.webclient).downloadstring($core_url)

# prep
assert_not_installed 'scoop'
$appdir = appdir 'scoop'
$abs_appdir = ensure $appdir

# download scoop zip
$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$abs_appdir\scoop.zip"
echo 'downloading...'
dl $zipurl $zipfile

echo 'extracting...'
unzip $zipfile $abs_appdir
rm $zipfile

echo 'creating stub...'
stub "$abs_appdir\scoop-master\bin\scoop.ps1"

ensure_scoop_in_path
success 'scoop was successfully installed!'
echo 'type "scoop help" for instructions'
