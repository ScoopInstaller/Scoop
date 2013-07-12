# usage: scoop uncache <app>
# summary: Remove an app from the download cache
param($app)

. "$psscriptroot\..\lib\help.ps1"

if(!$app) { 'ERROR: <app> missing'; my_usage; exit 1 }

rm "$scoopdir\cache\$app#*"