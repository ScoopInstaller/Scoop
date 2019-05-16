function persist_data($manifest, $original_dir, $persist_dir) {
    $persist = $manifest.persist
    if($persist) {
        $persist_dir = ensure $persist_dir

        if ($persist -isnot [Array]) {
            $persist = @($persist);
        }

        $persist | ForEach-Object {
            if ($_ -is [String] -or $_ -is [Array]) {
                $persist_def = persist_def_arr $_
            } else {
                $persist_def = persist_def_obj $_
            }
            debug $persist_def
            persist_core @persist_def
        }
    }
}

function persist_def_obj($persist) {
    $persist_def = @{}
    $persist_def.source = $persist.name.TrimEnd('/').TrimEnd('\')
    if ($persist.target) {
        $persist_def.target = $persist.target
    } else {
        $persist_def.target = $persist_def.source
    }

    if ($persist.type) {
        $type = $persist.type
    } elseif ($persist.name -match "[/\\]$") {
        $type = "directory"
    } else {
        $type = "file"
    }
    if ($null -eq $persist.glue) {
        $glue = "`r`n"
    } else {
        $glue = $persist.glue
    }
    if ($type -eq "file") {
        if ($persist.base64) {
            $persist_def.content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($persist.content -join ''))
        } else {
            $persist_def.content = $persist.content -join $glue
        }
    } else {
        $persist_def.content = $null
    }

    if ($persist.method) {
        $persist_def.method = $persist.method
    }

    if ($persist.encoding -and ($type -eq "file")) {
        $persist_def.encoding = $persist.encoding
    }

    return $persist_def
}
function persist_def_arr($persist) {
    if ($persist -is [Array]) {
        # if $persist is Array, use its length to determine its type
        switch ($persist.Count) {
            # lenght = 1, type is file
            1 { $source = $persist[0]; $target = $null; $content = "" }
            # length = 2, type is directory and persist to different name
            2 { $source = $persist[0]; $target = $persist[1]; $content = $null }
            # length > 2, type is file and the remaining rows are file content
            Default { $source = $persist[0]; $target = $persist[1]; $content = $persist[2..($persist.Count-1)] -join "`r`n" }
        }
    } else {
        # $persist is directory
        $source = $persist
        $target = $null
        $content = $null
    }

    if (!$target) {
        $target = $source
    }

    $persist_def = @{
        source = $source.TrimEnd('/').TrimEnd('\')
        target = $target
        content = $content
    }

    return $persist_def
}

function persist_core($source, $target, $content = $null, $method = "link", $encoding = "ASCII") {
    write-host "Persisting $source"

    $source = fullpath "$original_dir\$source"
    $target = fullpath "$persist_dir\$target"

    # if we have had persist data in the store, just create link and go
    if (Test-Path $target) {
        # if there is also a source data, using $method to determine what to do
        if (Test-Path $source) {
            if (is_directory $source) {
                # for dir persisting
                switch ($method) {
                    # keep $source
                    "copy" {
                        Remove-Item $target -Recurse -Force
                        movedir $source $target
                    }
                    # keep all files based on $target
                    "merge" { movedir $source $target "/XC /XN /XO" }
                    # keep all newer files
                    "update" { movedir $source $target "/XO" }
                    # keep $target ("link")
                    Default { movedir $source "$source.original" }
                }
            } else {
                # for file persisting
                switch ($method) {
                    # keep $source
                    "copy" { Move-Item $source $target -Force }
                    # keep newer
                    "update" {
                        if ((Get-Item $source).LastWriteTimeUtc -gt (Get-Item $target).LastWriteTimeUtc){
                            Move-Item $source $target -Force
                        } else {
                            Rename-Item $source "$source.original" -Force
                        }
                    }
                    # keep $target ("link", "merge")
                    Default { Rename-Item $source "$source.original" -Force }
                }
            }
        }
    # we don't have persist data in the store, move the source to target, then create link
    } elseif (Test-Path $source) {
        # ensure target parent folder exist
        $null = ensure (Split-Path -Path $target)
        Move-Item $source $target
    # use file content to determine $source's type, $null for directory and others for file
    } elseif ($null -eq $content) {
        New-Item $target -ItemType Directory -Force | Out-Null
    } else {
        $null = ensure (Split-Path -Path $target)
        $content = $ExecutionContext.InvokeCommand.ExpandString($content)
        Out-File -FilePath $target -Encoding $encoding -InputObject $content -Force
    }

    # create link
    if (is_directory $target) {
        # target is a directory, create junction
        create_junction $source $target | Out-Null
    } else {
        # target is a file, create hard link
        create_hardlink $source $target | Out-Null
    }
}
function unlink_persist_data($dir) {
    # unlink all junction / hard link in the directory
    Get-ChildItem -Recurse $dir | ForEach-Object {
        $file = $_
        if ($null -ne $file.LinkType) {
            Remove-Item $file.FullName -Recurse -Force
        }
    }
}

# check whether write permission for Users usergroup is set to global persist dir, if not then set
function persist_permission($manifest, $global) {
    if($global -and $manifest.persist -and (is_admin)) {
        $path = persistdir $null $global
        $user = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545'
        $target_rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, 'Write', 'ObjectInherit', 'none', 'Allow')
        $acl = Get-Acl -Path $path
        $acl.SetAccessRule($target_rule)
        $acl | Set-Acl -Path $path
    }
}
