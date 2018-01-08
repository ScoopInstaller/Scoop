# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | ?{ $_ -ne $null } | % {
        $target = $_.item(0)
        $name = $_.item(1)
        try {
            $arguments = $_.item(2)
        } catch {
            $arguments = ""
        }
        startmenu_shortcut "$dir\$target" $name $global $arguments
    }
}

function shortcut_folder($global) {
    if($global) {
        "$([environment]::getfolderpath('commonstartmenu'))\Programs\Scoop Apps"
        return
    }
    "$([environment]::getfolderpath('startmenu'))\Programs\Scoop Apps"
}

function startmenu_shortcut($target, $shortcutName, $global, $arguments) {
    if(!(Test-Path $target)) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find $target"
        return
    }
    $scoop_startmenu_folder = shortcut_folder $global
    if(!(Test-Path $scoop_startmenu_folder)) {
        New-Item $scoop_startmenu_folder -type Directory
    }
    $dirname = [System.IO.Path]::GetDirectoryName($shortcutName)
    if ($dirname) {
        $dirname = [io.path]::combine($scoop_startmenu_folder, $dirname)
        if(!(Test-Path $dirname)) {
            New-Item $dirname -type Directory
        }
    }
    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = "$target"
    if ($arguments) {
        $wsShell.Arguments = $arguments
    }
    $wsShell.Save()
    write-host "Creating shortcut for $shortcutName ($(fname $target))"
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | ?{ $_ -ne $null } | % {
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
