# helpers
function getenv($name) { [environment]::GetEnvironmentVariable($name, 'User') }
function setenv($name, $val) { [Environment]::SetEnvironmentVariable($name, $val, 'User') }

$bindir = "$env:localappdata\bin"
$scoopdir = "$env:localappdata\scoop"
if(test-path "$bindir") { echo "removing $bindir...";rm -r -force $bindir }
if(test-path "$scoopdir") { echo "removing $scoopdir...";rm -r -force $scoopdir }

$bindir_regex = [regex]::escape($bindir)
if((getenv 'path') -imatch $bindir_regex) {
  echo "removing $bindir from path"
  setenv 'path' ($env:path -replace $bindir_regex, '')
}