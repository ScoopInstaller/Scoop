#requires -v 3

# remote install:
#   iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
$erroractionpreference='stop' # quit if anything goes wrong

# get core functions
$core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
echo 'initializing...'
iex (new-object net.webclient).downloadstring($core_url)

# prep
if(installed 'scoop') {
	write-host "scoop is already installed. run 'scoop update' to get the latest version." -f red
	# don't abort if invoked with iex——that would close the PS session
	if($myinvocation.commandorigin -eq 'Internal') { return } else { exit 1 }
}
$dir = ensure (versiondir 'scoop' 'current')

# download scoop zip
$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$dir\scoop.zip"
echo 'downloading...'
dl $zipurl $zipfile

'extracting...'
unzip $zipfile $dir 'scoop-master'
rm $zipfile

$null > "$dir\last_updated" # save install timestamp

echo 'creating shim...'
shim "$dir\bin\scoop.ps1"

ensure_scoop_in_path
success 'scoop was installed successfully!'
echo "type 'scoop help' for instructions"
