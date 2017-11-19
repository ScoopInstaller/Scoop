<#
TODO
 - add a github release autoupdate type
 - tests (single arch, without hashes etc.)
 - clean up
#>
. "$psscriptroot\..\lib\json.ps1"

. "$psscriptroot/core.ps1"
. "$psscriptroot/json.ps1"

function find_hash_in_rdf([String] $url, [String] $filename) {
    $data = $null
    try {
        # Download and parse RDF XML file
        $wc = new-object net.webclient
        $wc.headers.add('Referer', (strip_filename $url))
        [xml]$data = $wc.downloadstring($url)
    } catch [system.net.webexception] {
        write-host -f darkred $_
        write-host -f darkred "URL $url is not valid"
        return $null
    }

    # Find file content
    $digest = $data.RDF.Content | ? { [String]$_.about -eq $filename }

    return format_hash $digest.sha256
}

function find_hash_in_textfile([String] $url, [String] $basename, [String] $regex) {
    $hashfile = $null

    try {
        $wc = new-object net.webclient
        $wc.headers.add('Referer', (strip_filename $url))
        $hashfile = $wc.downloadstring($url)
    } catch [system.net.webexception] {
        write-host -f darkred $_
        write-host -f darkred "URL $url is not valid"
        return
    }

    # find single line hash in $hashfile (will be overridden by $regex)
    if ($regex.Length -eq 0) {
        $normalRegex = "^([a-fA-F0-9]+)$"
    } else {
        $normalRegex = $regex
    }

    $normalRegex = substitute $normalRegex @{'$basename' = [regex]::Escape($basename)}
    if ($hashfile -match $normalRegex) {
        $hash = $matches[1]
    }

    # find hash with filename in $hashfile (will be overridden by $regex)
    if ($hash.Length -eq 0 -and $regex.Length -eq 0) {
        $filenameRegex = "([a-fA-F0-9]+)\s+(?:\.\/|\*)?(?:`$basename)(\s[\d]+)?"
        $filenameRegex = substitute $filenameRegex @{'$basename' = [regex]::Escape($basename)}
        if ($hashfile -match $filenameRegex) {
            $hash = $matches[1]
        }
    }

    return format_hash $hash
}

function find_hash_in_json([String] $url, [String] $basename, [String] $jsonpath) {
    $json = $null

    try {
        $wc = new-object net.webclient
        $wc.headers.add('Referer', (strip_filename $url))
        $json = $wc.downloadstring($url)
    } catch [system.net.webexception] {
        write-host -f darkred $_
        write-host -f darkred "URL $url is not valid"
        return
    }
    $hash = json_path $json $jsonpath $basename
    if(!$hash) {
        $hash = json_path_legacy $json $jsonpath $basename
    }
    return format_hash $hash
}

function get_hash_for_app([String] $app, $config, [String] $version, [String] $url, [Hashtable] $substitutions) {
    $hash = $null

    <#
    TODO implement more hashing types
    `extract` Should be able to extract from origin page source (checkver)
    `rdf` Find hash from a RDF Xml file
    `download` Last resort, download the real file and hash it
    #>
    $hashmode = $config.mode
    $basename = url_remote_filename($url)

    $hashfile_url = substitute $config.url @{
        '$url' = (strip_fragment $url);
        '$baseurl' = (strip_filename (strip_fragment $url)).TrimEnd('/')
        '$basename' = $basename
    }
    $hashfile_url = substitute $hashfile_url $substitutions
    if($hashfile_url) {
        write-host -f DarkYellow 'Searching hash for ' -NoNewline
        write-host -f Green $(url_remote_filename $url) -NoNewline
        write-host -f DarkYellow ' in ' -NoNewline
        write-host -f Green $hashfile_url
    }

    if($hashmode.Length -eq 0 -and $config.url.Length -ne 0) {
        $hashmode = 'extract'
    }

    if ($config.jp.Length -gt 0) {
        $hashmode = 'json'
    }

    if (!$hashfile_url -and $url -match "(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*)") {
        $hashmode = 'sourceforge'
        # change the URL because downloads.sourceforge.net doesn't have checksums
        $hashfile_url = (strip_filename (strip_fragment "https://sourceforge.net/projects/$($matches['project'])/files/$($matches['file'])")).TrimEnd('/')
        $hash = find_hash_in_textfile $hashfile_url $basename '"$basename":.*?"sha1":\s"([a-fA-F0-9]{40})"'
    }

    if ($hashmode -eq 'extract') {
        $hash = find_hash_in_textfile $hashfile_url $basename $config.find
    }

    if ($hashmode -eq 'json') {
        $hash = find_hash_in_json $hashfile_url $basename $config.jp
    }

    if ($hashmode -eq 'rdf') {
        $hash = find_hash_in_rdf $hashfile_url $basename
    }

    if($hash) {
        # got one!
        write-host -f DarkYellow 'Found: ' -NoNewline
        write-host -f Green $hash -NoNewline
        write-host -f DarkYellow ' using ' -NoNewline
        write-host -f Green  "$((Get-Culture).TextInfo.ToTitleCase($hashmode)) Mode"
        return $hash
    } elseif($hashfile_url) {
        write-host -f DarkYellow "Could not find hash in $hashfile_url"
    }

    write-host -f DarkYellow 'Downloading ' -NoNewline
    write-host -f Green $(url_remote_filename $url) -NoNewline
    write-host -f DarkYellow ' to compute hashes!'
    try {
        dl_with_cache $app $version $url $null $null $true
    } catch [system.net.webexception] {
        write-host -f darkred $_
        write-host -f darkred "URL $url is not valid"
        return $null
    }
    $file = fullpath (cache_path $app $version $url)
    $hash = compute_hash $file 'sha256'
    write-host -f DarkYellow 'Computed hash: ' -NoNewline
    write-host -f Green $hash
    return $hash
}

function update_manifest_with_new_version($json, [String] $version, [String] $url, [String] $hash, $architecture = $null) {
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
}

function update_manifest_prop([String] $prop, $json, [Hashtable] $substitutions) {
    # first try the global property
    if ($json.$prop -and $json.autoupdate.$prop) {
        $json.$prop = substitute $json.autoupdate.$prop $substitutions
    }

    # check if there are architecture specific variants
    if ($json.architecture -and $json.autoupdate.architecture) {
        $json.architecture | Get-Member -MemberType NoteProperty | % {
            $architecture = $_.Name
            if ($json.architecture.$architecture.$prop -and $json.autoupdate.architecture.$architecture.$prop) {
                $json.architecture.$architecture.$prop = substitute (arch_specific $prop $json.autoupdate $architecture) $substitutions
            }
        }
    }
}

function get_version_substitutions([String] $version, [Hashtable] $matches) {
    $firstPart = $version.Split('-') | Select-Object -first 1
    $lastPart = $version.Split('-') | Select-Object -last 1
    $versionVariables = @{
        '$version' = $version;
        '$underscoreVersion' = ($version -replace "\.", "_");
        '$dashVersion' = ($version -replace "\.", "-");
        '$cleanVersion' = ($version -replace "\.", "");
        '$majorVersion' = $firstPart.Split('.') | Select-Object -first 1;
        '$minorVersion' = $firstPart.Split('.') | Select-Object -skip 1 -first 1;
        '$patchVersion' = $firstPart.Split('.') | Select-Object -skip 2 -first 1;
        '$buildVersion' = $firstPart.Split('.') | Select-Object -skip 3 -first 1;
        '$preReleaseVersion' = $lastPart;
    }
    if($matches) {
        $matches.GetEnumerator() | % {
            if($_.Name -ne "0") {
                $versionVariables.Add('$match' + (Get-Culture).TextInfo.ToTitleCase($_.Name), $_.Value)
            }
        }
    }
    return $versionVariables
}

function autoupdate([String] $app, $dir, $json, [String] $version, [Hashtable] $matches) {
    Write-Host -f DarkCyan "Autoupdating $app"
    $has_changes = $false
    $has_errors = $false
    [Bool]$valid = $true
    $substitutions = get_version_substitutions $version $matches

    if ($json.url) {
        # create new url
        $url   = substitute $json.autoupdate.url $substitutions
        $valid = $true

        if($valid) {
            # create hash
            $hash = get_hash_for_app $app $json.autoupdate.hash $version $url $substitutions
            if ($hash -eq $null) {
                $valid = $false
                Write-Host -f DarkRed "Could not find hash!"
            }
        }

        # write changes to the json object
        if ($valid) {
            $has_changes = $true
            update_manifest_with_new_version $json $version $url $hash
        } else {
            $has_errors = $true
            throw "Could not update $app"
        }
    } else {
        $json.architecture | Get-Member -MemberType NoteProperty | % {
            $valid = $true
            $architecture = $_.Name

            # create new url
            $url   = substitute (arch_specific "url" $json.autoupdate $architecture) $substitutions
            $valid = $true

            if($valid) {
                # create hash
                $hash = get_hash_for_app $app (arch_specific "hash" $json.autoupdate $architecture) $version $url $substitutions
                if ($hash -eq $null) {
                    $valid = $false
                    Write-Host -f DarkRed "Could not find hash!"
                }
            }

            # write changes to the json object
            if ($valid) {
                $has_changes = $true
                update_manifest_with_new_version $json $version $url $hash $architecture
            } else {
                $has_errors = $true
                throw "Could not update $app $architecture"
            }
        }
    }

    # update properties
    update_manifest_prop "extract_dir" $json $substitutions

    # update license
    update_manifest_prop "license" $json $substitutions

    if ($has_changes -and !$has_errors) {
        # write file
        Write-Host -f DarkGreen "Writing updated $app manifest"

        $path = join-path $dir "$app.json"

        $file_content = $json | ConvertToPrettyJson
        [System.IO.File]::WriteAllLines($path, $file_content)

        # notes
        if ($json.autoupdate.note) {
            Write-Host ""
            Write-Host -f DarkYellow $json.autoupdate.note
        }
    } else {
        Write-Host -f DarkGray "No updates for $app"
    }
}
