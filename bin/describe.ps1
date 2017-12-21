param($app, $dir)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\description.ps1"

if(!$dir) {
    $dir = "$psscriptroot\..\bucket"
}
$dir = resolve-path $dir

$search = "*"
if($app) { $search = $app }

# get apps to check
$apps = @()
gci $dir "$search.json" | % {
    $json = parse_json "$dir\$_"
    $apps += ,@(($_ -replace '\.json$', ''), $json)
}

$apps |% {
    $app, $json = $_
    write-host "$app`: " -nonewline

    if(!$json.homepage) {
        write-host "`nNo homepage set." -fore red
        return
    }
    # get description from homepage
    try {
        $home_html = (new-object net.webclient).downloadstring($json.homepage)
    } catch {
        write-host "`n$($_.exception.message)" -fore red
        return
    }

    $description, $descr_method = find_description $json.homepage $home_html
    if(!$description) {
        write-host -fore red "`nDescription not found ($($json.homepage))"
        return
    }

    $description = clean_description $description

    write-host "(found by $descr_method)"
    write-host "  ""$description""" -fore green

}

