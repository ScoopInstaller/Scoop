# get core functions
$init_url = 'https://raw.github.com/lukesampson/scoop/master/lib/init.ps1'
echo 'initializing...'
iex (new-object net.webclient).downloadstring($init_url)

# prep
assert_not_installed 'scoop' 'bootstrap'
$appdir = appdir 'scoop' 'bootstrap')
$abs_appdir = ensure $appdir

# download scoop zip
$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$abs_appdir\scoop.zip"
echo 'downloading...'
dl $zipurl $zipurl

echo 'extracting...'
unzip $zipurl $abs_appdir
rm $zipurl

echo 'creating stub...'
stub "$abs_appdir\scoop.ps1"

ensure_scoop_in_path
success 'you successfully installed scoop!'
echo 'type "scoop help" for instructions'
