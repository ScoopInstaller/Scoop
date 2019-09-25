function Add-PersistentLink {
    param (
        [Object[]]
        $Persist,
        [String]
        $InstalledPath,
        [String]
        $PersistentPath
    )

    process {
        debug $Persist
        if ($Persist) {
            $Persist | ForEach-Object {
                $persistDef = Get-PersistentDefination $_
                $persistDef.Source = "$InstalledPath\$($persistDef.Source)"
                $persistDef.Target = "$PersistentPath\$($persistDef.Target)"
                debug $persistDef
                PersistentHelper @PersistDef
            }
        }
    }
}
function persist_data($manifest, $original_dir, $persist_dir) {
    Show-DeprecatedWarning $MyInvocation 'Add-PersistentLink'
    Add-PersistentLink -Persist $manifest.persist -InstalledPath $original_dir -PersistentPath $persist_dir
}

function Get-PersistentDefination {
    param (
        [Object]
        $Persist
    )

    $persistDef = @{ }

    switch ($Persist.GetType().Name) {
        'PSCustomObject' {
            $persistDef.Source = $Persist.name
            $persistDef.Target = $Persist.target

            # if there is no $Persist.type, try to determine type from trailing slash
            if ($Persist.type) {
                $type = $Persist.type
            } elseif ($Persist.name -match "[/\\]$") {
                $type = 'directory'
            } else {
                $type = 'file'
            }
            # combine $Persist.glue and $Persist.content to file content
            # directory has $null file content
            if ($null -eq $Persist.glue) {
                $glue = "`r`n"
            } else {
                $glue = $Persist.glue
            }
            if ($type -eq 'file') {
                if ($Persist.base64) {
                    $persistDef.Content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Persist.content -join ''))
                } else {
                    $persistDef.Content = $Persist.content -join $glue
                }
            }

            if ($Persist.method) {
                $persistDef.Method = $Persist.method
            }

            if ($Persist.encoding -and ($type -eq "file")) {
                $persistDef.Encoding = $Persist.encoding
            }
        }
        'Object[]' {
            # if $Persist is [Array], use its length to determine its type
            switch ($Persist.Count) {
                # lenght = 1, type is file
                1 {
                    $persistDef.Source = $Persist[0]
                    $persistDef.Content = ""
                }
                # length = 2, type is directory and persist to different name
                2 {
                    $persistDef.Source = $Persist[0]
                    $persistDef.Target = $Persist[1]
                }
                # length > 2, type is file and the remaining rows are file content
                Default {
                    $persistDef.Source = $Persist[0]
                    $persistDef.Target = $Persist[1]
                    $persistDef.Content = $Persist[2..($Persist.Count - 1)] -join "`r`n"
                }
            }
        }
        'String' {
            # $Persist is [String]
            $persistDef.Source = $Persist
        }
    }

    $persistDef.Source = $persistDef.Source.TrimEnd('\/')
    # $persistDef.target is $null or empty string
    if (!$persistDef.Target) {
        $persistDef.Target = $persistDef.Source
    }

    return $persistDef
}

function PersistentHelper {
    <#
    .SYNOPSIS
        Core persistence helper function
    .DESCRIPTION
        Persist data to some location according to given parameters.
    .PARAMETER Source
        File or directory to be persisted
    .PARAMETER Target
        Target store location of persisted item
    .PARAMETER Content
        File content if target file not existed, $null for directory
    .PARAMETER Method
        Persisting method, one of copy, merge, update or link
    .PARAMETER Encoding
        Encoding of new file
    #>
    param (
        [String]
        $Source,
        [String]
        $Target,
        [String]
        $Content = $null,
        [String]
        $Method = 'link',
        [String]
        $Encoding = 'ASCII'
    )

    Write-Host "Persisting $Source"
    # if we have had persist data in the store, just create link and go
    if (Test-Path $Target) {
        # if there is also a source data, using $Method to determine what to do
        if (Test-Path $Source) {
            if (Confirm-IsDirectory $Source) {
                # for dir persisting
                switch ($Method) {
                    # keep $Source
                    'copy' {
                        Remove-Item -Path $Target -Recurse -Force
                        Move-Directory -Path $Source -Destination $Target
                    }
                    # keep all files based on $Target
                    'merge' { Move-Directory -Path $Source -Destination $Target -ArgumentList 'Merge' }
                    # keep all newer files
                    'update' { Move-Directory -Path $Source -Destination $Target -ArgumentList 'Update' }
                    # keep $Target ("link")
                    Default { Move-Directory -Path $Source -Destination "$Source.original" }
                }
            } else {
                # for file persisting
                switch ($Method) {
                    # keep $Source
                    'copy' { Move-Item $Source $Target -Force }
                    # keep newer
                    'update' {
                        if ((Get-Item $Source).LastWriteTimeUtc -gt (Get-Item $Target).LastWriteTimeUtc){
                            Move-Item $Source $Target -Force
                        } else {
                            Rename-Item $Source "$Source.original" -Force
                        }
                    }
                    # keep $Target ("link", "merge")
                    Default { Rename-Item $Source "$Source.original" -Force }
                }
            }
        }
    # we don't have persist data in the store, move the source to target, then create link
    } elseif (Test-Path $Source) {
        # ensure target parent folder exist
        ensure (Split-Path -Path $Target) | Out-Null
        Move-Directory -Path $Source -Destination $Target
    # use file content to determine $Source's type, $null for directory and others for file
    } elseif ($null -eq $Content) {
        New-Item $Target -ItemType Directory -Force | Out-Null
    } else {
        ensure (Split-Path -Path $Target) | Out-Null
        $Content = $ExecutionContext.InvokeCommand.ExpandString($Content)
        Out-File -FilePath $Target -Encoding $Encoding -InputObject $Content -Force
    }

    # create link
    if (Confirm-IsDirectory $Target) {
        # target is a directory, create junction
        Set-Junction -Path $Source -Target $Target | Out-Null
    } else {
        # target is a file, create hard link
        Set-HardLink -Path $Source -Target $Target | Out-Null
    }
}

function Remove-PersistentLink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [String]
        $Path
    )
    # unlink all junction / hard link in the directory
    Get-ChildItem -Recurse $Path | ForEach-Object {
        if ($null -ne $_.LinkType) {
            Remove-Item $_.FullName -Recurse -Force
        }
    }
}

# check whether write permission for Users usergroup is set to global persist dir, if not then set
function Set-PersistentPermission {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [PSObject]
        $Manifest,
        [Switch]
        $Global
    )
    if ($Global -and $Manifest.persist -and (is_admin)) {
        $Path = persistdir $null $true
        $User = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545'
        $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, 'Write', 'ObjectInherit', 'none', 'Allow')
        $Acl = Get-Acl -Path $Path
        $Acl.SetAccessRule($Rule)
        $Acl | Set-Acl -Path $Path
    }
}
