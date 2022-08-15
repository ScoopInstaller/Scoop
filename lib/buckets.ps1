$bucketsdir = "$scoopdir\buckets"

function Find-BucketDirectory {
    <#
    .DESCRIPTION
        Return full path for bucket with given name.
        Main bucket will be returned as default.
    .PARAMETER Name
        Name of bucket.
    .PARAMETER Root
        Root folder of bucket repository will be returned instead of 'bucket' subdirectory (if exists).
    #>
    param(
        [string] $Name = 'main',
        [switch] $Root
    )

    # Handle info passing empty string as bucket ($install.bucket)
    if (($null -eq $Name) -or ($Name -eq '')) {
        $Name = 'main'
    }
    $bucket = "$bucketsdir\$Name"

    if ((Test-Path "$bucket\bucket") -and !$Root) {
        $bucket = "$bucket\bucket"
    }

    return $bucket
}

function bucketdir($name) {
    Show-DeprecatedWarning $MyInvocation 'Find-BucketDirectory'

    return Find-BucketDirectory $name
}

function known_bucket_repos {
    $json = "$PSScriptRoot\..\buckets.json"

    return Get-Content $json -Raw | ConvertFrom-Json -ErrorAction stop
}

function known_bucket_repo($name) {
    $buckets = known_bucket_repos
    $buckets.$name
}

function known_buckets {
    known_bucket_repos | ForEach-Object { $_.PSObject.Properties | Select-Object -Expand 'name' }
}

function apps_in_bucket($dir) {
    return (Get-ChildItem $dir -Filter '*.json' -Recurse).BaseName
}

function Get-LocalBucket {
    <#
    .SYNOPSIS
        List all local buckets.
    #>
    $bucketNames = (Get-ChildItem -Path $bucketsdir -Directory).Name
    if ($null -eq $bucketNames) {
        return @() # Return a zero-length list instead of $null.
    } else {
        return $bucketNames
    }
}

function buckets {
    Show-DeprecatedWarning $MyInvocation 'Get-LocalBucket'

    return Get-LocalBucket
}

function Convert-RepositoryUri {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [String] $Uri
    )

    process {
        # https://git-scm.com/docs/git-clone#_git_urls
        # https://regex101.com/r/xGmwRr/1
        if ($Uri -match '(?:@|/{1,3})(?:www\.|.*@)?(?<provider>[^/]+?)(?::\d+)?[:/](?<user>.+)/(?<repo>.+?)(?:\.git)?/?$') {
            $Matches.provider, $Matches.user, $Matches.repo -join '/'
        } else {
            error "$Uri is not a valid Git URL!"
            error "Please see https://git-scm.com/docs/git-clone#_git_urls for valid ones."
            return $null
        }
    }
}

function list_buckets {
    $buckets = @()
    Get-LocalBucket | ForEach-Object {
        $bucket = [Ordered]@{ Name = $_ }
        $path = Find-BucketDirectory $_ -Root
        if ((Test-Path (Join-Path $path '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
            $bucket.Source = git -C $path config remote.origin.url
            $bucket.Updated = git -C $path log --format='%aD' -n 1 | Get-Date
        } else {
            $bucket.Source = friendly_path $path
            $bucket.Updated = (Get-Item "$path\bucket").LastWriteTime
        }
        $bucket.Manifests = Get-ChildItem "$path\bucket" -Force -Recurse -ErrorAction SilentlyContinue |
                Measure-Object | Select-Object -ExpandProperty Count
        $buckets += [PSCustomObject]$bucket
    }
    ,$buckets
}

function add_bucket($name, $repo) {
    if (!(Test-CommandAvailable git)) {
        error "Git is required for buckets. Run 'scoop install git' and try again."
        return 1
    }

    $dir = Find-BucketDirectory $name -Root
    if (Test-Path $dir) {
        warn "The '$name' bucket already exists. To add this bucket again, first remove it by running 'scoop bucket rm $name'."
        return 2
    }

    $uni_repo = Convert-RepositoryUri -Uri $repo
    if ($null -eq $uni_repo) {
        return 1
    }
    foreach ($bucket in Get-LocalBucket) {
        if (Test-Path -Path "$bucketsdir\$bucket\.git") {
            $remote = git -C "$bucketsdir\$bucket" config --get remote.origin.url
            if ((Convert-RepositoryUri -Uri $remote) -eq $uni_repo) {
                warn "Bucket $bucket already exists for $repo"
                return 2
            }
        }
    }

    Write-Host 'Checking repo... ' -NoNewline
    $out = git_cmd ls-remote $repo 2>&1
    if ($LASTEXITCODE -ne 0) {
        error "'$repo' doesn't look like a valid git repository`n`nError given:`n$out"
        return 1
    }
    ensure $bucketsdir | Out-Null
    $dir = ensure $dir
    git_cmd clone "$repo" "`"$dir`"" -q
    Write-Host 'OK'
    success "The $name bucket was added successfully."
    return 0
}

function rm_bucket($name) {
    $dir = Find-BucketDirectory $name -Root
    if (!(Test-Path $dir)) {
        error "'$name' bucket not found."
        return 1
    }

    Remove-Item $dir -Recurse -Force -ErrorAction Stop
    return 0
}

function new_issue_msg($app, $bucket, $title, $body) {
    $app, $manifest, $bucket, $url = Get-Manifest "$bucket/$app"
    $url = known_bucket_repo $bucket
    $bucket_path = "$bucketsdir\$bucket"

    if (Test-Path $bucket_path) {
        $remote = git -C "$bucket_path" config --get remote.origin.url
        # Support ssh and http syntax
        # git@PROVIDER:USER/REPO.git
        # https://PROVIDER/USER/REPO.git
        $remote -match '(@|:\/\/)(?<provider>.+)[:/](?<user>.*)\/(?<repo>.*)(\.git)?$' | Out-Null
        $url = "https://$($Matches.Provider)/$($Matches.User)/$($Matches.Repo)"
    }

    if (!$url) { return 'Please contact the bucket maintainer!' }

    # Print only github repositories
    if ($url -like '*github*') {
        $title = [System.Web.HttpUtility]::UrlEncode("$app@$($manifest.version): $title")
        $body = [System.Web.HttpUtility]::UrlEncode($body)
        $url = $url -replace '\.git$', ''
        $url = "$url/issues/new?title=$title"
        if ($body) {
            $url += "&body=$body"
        }
    }

    $msg = "`nPlease try again or create a new issue by using the following link and paste your console output:"
    return "$msg`n$url"
}
