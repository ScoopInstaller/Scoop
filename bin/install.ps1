#requires -v 3

# remote install:
#   iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
$erroractionpreference='stop' # quit if anything goes wrong

# show notification to change execution policy:
if((get-executionpolicy) -gt 'RemoteSigned') {
    "PowerShell requires an execution policy of 'RemoteSigned' to run Scoop."
    "To make this change please run:"
    "'Set-ExecutionPolicy RemoteSigned -scope CurrentUser'"
    break
}

# get core functions
$core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
echo 'Initializing...'
iex (new-object net.webclient).downloadstring($core_url)

# prep
if(installed 'scoop') {
    write-host "Scoop is already installed. Run 'scoop update' to get the latest version." -f red
    # don't abort if invoked with iex——that would close the PS session
    if($myinvocation.mycommand.commandtype -eq 'Script') { return } else { exit 1 }
}
$dir = ensure (versiondir 'scoop' 'current')

# download scoop zip
$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$dir\scoop.zip"
echo 'Downloading...'
dl $zipurl $zipfile

'Extracting...'
unzip $zipfile "$dir\_tmp"
cp "$dir\_tmp\scoop-master\*" $dir -r -force
rm "$dir\_tmp" -r -force
rm $zipfile

echo 'Creating shim...'
shim "$dir\bin\scoop.ps1" $false

ensure_robocopy_in_path
ensure_scoop_in_path
success 'Scoop was installed successfully!'
echo "Type 'scoop help' for instructions."
