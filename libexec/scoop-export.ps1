# Usage: scoop export > filename
# Summary: Exports (an importable) list of installed apps
# Help: Lists all installed apps.

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"

$local = installed_apps $false | % { @{ name = $_; global = $false } }
$global = installed_apps $true | % { @{ name = $_; global = $true } }

$apps = @($local) + @($global)
$count = 0

# json
# echo "{["

if($apps) {
	$apps | sort { $_.name } | ? { !$query -or ($_.name -match $query) } | % {
        $app = $_.name
        $global = $_.global
        $ver = current_version $app $global
        $global_display = $null; if($global) { $global_display = '*global*'}

        # json
        # $val = "{ 'name': '$app', 'version': '$ver', 'global': $($global.toString().tolower()) }"
        # if($count -gt 0) {
        #     " ," + $val
        # } else {
        #     "  " + $val
        # }

        # "$app (v:$ver) global:$($global.toString().tolower())"
        "$app (v:$ver) $global_display"

        $count++
	}
}

# json
# echo "]}"

exit 0
