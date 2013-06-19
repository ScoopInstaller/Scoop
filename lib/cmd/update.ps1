# Usage: scoop update [app]
# Summary: Update an app, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update [app]' installs a new version of that app, if there is one.
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

if($app) { abort "updating apps isn't implemented yet" }

# update scoop
$tempdir = "$scoopdir\temp"
if(test-path $tempdir) {
    try { rm $tempdir -ea 0 } catch { abort "couldn't remove $tempdir: it may be in use" }
}
mkdir $tempdir



$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$tempdir\scoop.zip"
echo 'downloading...'
dl $zipurl $zipfile

echo 'extracting...'
unzip $zipfile $abs_appdir
rm $zipfile