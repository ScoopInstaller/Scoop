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
    $response = Invoke-WebRequest -Uri $url -Method HEAD
    if ($response.StatusCode.Equals(200)) { # redirects might be ok
        return $true
    }

    return $false
}

function autoupdate([String] $app, $json, [String] $version)
{
    Write-Host -f DarkCyan "Autoupdating $app"
    $has_changes = $false
    $has_errors = $false

    $json.architecture | Get-Member -MemberType NoteProperty | % {
        [Bool]$valid = $true
        $architecture = $_.Name

        # create new url
        <#
        TODO There should be a second option to extract the url from the page
        #>
        $template = $json.autoupdate.url.$architecture;
        $url = substitute $template @{'$version' = $version}

        # check url
        if (!(check_url $url)) {
            $valid = $false
            Write-Host -f DarkRed "URL $url is not valid"
        }

        # create hash
        <#
        TODO implement more hashing types
        `extract` Should be able to extract from origin page source (checkver)
        `download` Last resort, download the real file and hash it
        #>
        $hashmode = $json.autoupdate.hash.mode;
        if ($hashmode -eq "extract") {
            $hashfile_url = substitute $json.autoupdate.hash.url @{'$version' = $version; '$url' = $url};
            $hashfile = (new-object net.webclient).downloadstring($hashfile_url)

            $basename = fname($url)
            $regex = substitute $json.autoupdate.hash.find @{'$basename' = [regex]::Escape($basename)}

            if ($hashfile -match $regex) {
                $hash = $matches[1]

                if ($json.autoupdate.hash.type -eq "sha1") {
                    $hash = "sha1:$hash"
                }
            } else {
                $valid = $false
                Write-Error "could no find hash in hashfile"
            }
        }

        # write changes to the json object
        if ($valid) {
            $has_changes = $true
            $json.version = $version

            # If there are multiple urls we replace the first one
            if ($json.architecture.$architecture.url -is [System.Array]) {
                $json.architecture.$architecture.url[0] = $url
                $json.architecture.$architecture.hash[0] = $hash
            } else {
                $json.architecture.$architecture.url = $url
                $json.architecture.$architecture.hash = $hash
            }
        } else {
            $has_errors = $true
            Write-Host -f DarkRed "Could not update $app $architecture"
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
