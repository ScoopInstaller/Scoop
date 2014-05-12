. "$psscriptroot/../lib/config.ps1"

$url = 'http://scoop.sh'

$wc = new-object net.webclient
$wc.proxy.getproxy($url)

$wc.downloadstring($url)