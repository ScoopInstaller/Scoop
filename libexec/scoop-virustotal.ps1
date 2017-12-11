# Usage: scoop virustotal <app> [options]
# Summary: Look for app's SHA256 on virustotal.com
# Help: Look for app's SHA256 on virustotal.com
#
# The download's hash is also a key to access VirusTotal's scan results.
# This allows to check the safety of the files without even downloading
# them in many cases.
#
# Options:
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"

reset_aliases

$opt, $apps, $err = getopt $args 'a:' 'arch='
if($err) { "scoop virustotal: $err"; exit 1 }
$architecture = ensure_architecture ($opt.a + $opt.arch)

if($apps) {
    $apps | % {
        $manifest, $bucket = find_manifest $_
        if($manifest) {
            if([string]::isnullorempty($manifest.homepage)) {
                abort "Could not find homepage in manifest for '$_'."
            }
            $h = hash $manifest $architecture
            if ($h) {
                $h | % { start "https://www.virustotal.com/#/file/$_/detection" }
            }
            else {
                write-host -f darkred "No hash information for $_"
            }
        }
        else {
            abort "Could not find manifest for '$app'."
        }
    }
} else { my_usage }

exit 0
