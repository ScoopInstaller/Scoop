<#
TODO
 - add a github release autoupdate type
 - tests (single arch, without hashes etc.)
 - clean up
#>

function substitute([String] $str, [Hashtable] $params) {
    $params.GetEnumerator() | % {
        $str = $str.Replace($_.Name, $_.Value);
    }

    return $str
}

function check_url([String] $url) {
    if ($url.Contains("github.com")) {
        # github does not allow HEAD requests
        warn "Unable to check github url (assuming it is ok)"
        return $true;
    }

    $response = Invoke-WebRequest -Uri $url -Method HEAD
    if ($response.StatusCode.Equals(200)) { # redirects might be ok
        return $true
    }

    return $false
}

function getHash([String] $app, $config, [String] $version, [String] $url)
{
    $hash = $null

    <#
    TODO implement more hashing types
    `extract` Should be able to extract from origin page source (checkver)
    `download` Last resort, download the real file and hash it
    #>
    $hashmode = $config.mode;
    if ($hashmode -eq "extract") {
        $hashfile_url = substitute $config.url @{'$version' = $version; '$url' = $url};
        $hashfile = (new-object net.webclient).downloadstring($hashfile_url)

        $basename = fname($url)
        $regex = substitute $config.find @{'$basename' = [regex]::Escape($basename)}

        if ($hashfile -match $regex) {
            $hash = $matches[1]

            if ($config.type -eq "sha1") {
                $hash = "sha1:$hash"
            }
        }
    } elseif ($hashmode -eq "download") {
        dl_with_cache $app $version $url $null $null $true
        $file = fullpath (cache_path $app $version $url)
        return compute_hash $file "sha256"
    } else {
        Write-Host "Unknown hashmode $hashmode"
    }

    return $hash
}

function updateJsonFileWithNewVersion($json, [String] $version, [String] $url, [String] $hash, $architecture = $null)
{
    $json.version = $version

    if ($architecture -eq $null) {
        if ($json.url -is [System.Array]) {
            $json.url[0] = $url
            $json.hash[0] = $hash
        } else {
            $json.url = $url
            $json.hash = $hash
        }
    } else {
        # If there are multiple urls we replace the first one
        if ($json.architecture.$architecture.url -is [System.Array]) {
            $json.architecture.$architecture.url[0] = $url
            $json.architecture.$architecture.hash[0] = $hash
        } else {
            $json.architecture.$architecture.url = $url
            $json.architecture.$architecture.hash = $hash
        }
    }

    if ($json.extract_dir -and $json.autoupdate.extract_dir) {
        $json.extract_dir = substitute $json.autoupdate.extract_dir @{'$version' = $version}
    }
}

function prepareDownloadUrl([String] $template, [String] $version)
{
    <#
    TODO There should be a second option to extract the url from the page
    #>
    return substitute $template @{'$version' = $version}
}

function autoupdate([String] $app, $json, [String] $version)
{
    Write-Host -f DarkCyan "Autoupdating $app"
    $has_changes = $false
    $has_errors = $false
    [Bool]$valid = $true

    if ($json.url) {
        # create new url
        $url = prepareDownloadUrl $json.autoupdate.url $version

        # check url
        if (!(check_url $url)) {
            $valid = $false
            Write-Host -f DarkRed "URL $url is not valid"
        }

        # create hash
        $hash = getHash $app $json.autoupdate.hash $version $url
        if ($hash -eq $null) {
            $valid = $false
            Write-Host -f DarkRed "Could not find hash!"
        }

        # write changes to the json object
        if ($valid) {
            $has_changes = $true
            updateJsonFileWithNewVersion $json $version $url $hash
        } else {
            $has_errors = $true
            Write-Host -f DarkRed "Could not update $app"
        }
    } else {
        $json.architecture | Get-Member -MemberType NoteProperty | % {
            $valid = $true
            $architecture = $_.Name

            # create new url
            $url = prepareDownloadUrl $json.autoupdate.url.$architecture $version

            # check url
            if (!(check_url $url)) {
                $valid = $false
                Write-Host -f DarkRed "URL $url is not valid"
            }

            # create hash
            $hash = getHash $app $json.autoupdate.hash $version $url
            if ($hash -eq $null) {
                $valid = $false
                Write-Host -f DarkRed "Could not find hash!"
            }

            # write changes to the json object
            if ($valid) {
                $has_changes = $true
                updateJsonFileWithNewVersion $json $version $url $hash $architecture
            } else {
                $has_errors = $true
                Write-Host -f DarkRed "Could not update $app $architecture"
            }
        }
    }

    if ($has_changes -and !$has_errors) {
        # write file
        Write-Host -f DarkGreen "Writing updated $app manifest"

        $path = manifest_path $app

        $file_content = $json | ConvertToPrettyJson
        [System.IO.File]::WriteAllLines($path, $file_content)
    } else {
        Write-Host -f DarkGray "No updates for $app"
    }
}
