# Usage: scoop update [app]
# Summary: Update an app, or Scoop itself
# Help: 'scoop update' updates Scoop to the latest version.
# 'scoop update [app]' installs a new version of that app, if there is one.
param($app)

. "$(split-path $myinvocation.mycommand.path)\..\core.ps1"

if($app) { abort "updating apps isn't implemented yet" }

# update scoop
$tempdir = versiondir 'scoop' 'update'
$currentdir = versiondir 'scoop' 'current'

if(test-path $tempdir) {
    try { rm -r $tempdir -ea stop -force } catch { abort "couldn't remove $tempdir`: it may be in use" }
}
$tempdir = ensure $tempdir

$zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
$zipfile = "$tempdir\scoop.zip"
echo 'downloading...'
dl $zipurl $zipfile

echo 'extracting...'
unzip $zipfile $tempdir
rm $zipfile

echo 'replacing files..'
rm -r -force $currentdir -ea stop
rni $tempdir 'current' -ea stop

ensure_scoop_in_path
success 'scoop was updated successfully!'