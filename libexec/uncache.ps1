# usage: scoop uncache <app>
# summary: Remove an app from the download cache
param($app)

rm "$scoopdir\cache\$app#*"