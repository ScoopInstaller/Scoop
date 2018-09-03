# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
        $target = [System.IO.Path]::Combine($dir, $_.item(0))
        $target = New-Object System.IO.FileInfo($target)
        $name = $_.item(1)
        $arguments = ""
        $icon = $null
        if($_.length -ge 3) {
            $arguments = $_.item(2)
        }
        if($_.length -ge 4) {
            $icon = [System.IO.Path]::Combine($dir, $_.item(3))
            $icon = New-Object System.IO.FileInfo($icon)
        }
        $arguments = (substitute $arguments @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir})
        startmenu_shortcut $target $name $arguments $icon $global
    }
}

function shortcut_folder($global) {
    $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('startmenu'), 'Programs', 'Scoop Apps')
    if($global) {
        $directory = [System.IO.Path]::Combine([Environment]::GetFolderPath('commonstartmenu'), 'Programs', 'Scoop Apps')
    }
    return $(ensure $directory)
}

function startmenu_shortcut([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global) {
    if(!$target.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find $target"
        return
    }
    if($icon -and !$icon.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find icon $icon"
        return
    }

    $scoop_startmenu_folder = shortcut_folder $global
    $subdirectory = [System.IO.Path]::GetDirectoryName($shortcutName)
    if ($subdirectory) {
        $subdirectory = ensure $([System.IO.Path]::Combine($scoop_startmenu_folder, $subdirectory))
    }

    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = $target.FullName
    $wsShell.WorkingDirectory = $target.DirectoryName
    if ($arguments) {
        $wsShell.Arguments = $arguments
    }
    if($icon -and $icon.Exists) {
        $wsShell.IconLocation = $icon.FullName
    }
    $wsShell.Save()
    write-host "Creating shortcut for $shortcutName ($(fname $target))"
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
        $name = $_.item(1)
        $shortcut = "$(shortcut_folder $global)\$name.lnk"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item $shortcut
        }
        # Before issue 1514 Startmenu shortcut removal
        #
        # Shortcuts that should have been installed globally would
        # have been installed locally up until 27 June 2017.
        #
        # TODO: Remove this 'if' block and comment after
        #       27 June 2018.
        if($global) {
            $shortcut = "$(shortcut_folder $false)\$name.lnk"
            if(Test-Path -Path $shortcut) {
                 Remove-Item $shortcut
            }
        }
    }
}
