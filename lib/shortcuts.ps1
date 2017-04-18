# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global) {
    $manifest.shortcuts | ?{ $_ -ne $null } | % {
        $target = $_.item(0)
        $name = $_.item(1)
        startmenu_shortcut "$dir\$target" $name
    }
}

function shortcut_folder() {
    "$([environment]::getfolderpath('startmenu'))\Programs\Scoop Apps"
}

function startmenu_shortcut($target, $shortcutName) {
    if(!(Test-Path $target)) {
        Write-Host -f DarkRed "Can't create the Startmenu shortcut for $(fname $target): Couldn't find $target"
        return
    }
    $scoop_startmenu_folder = shortcut_folder
    if(!(Test-Path $scoop_startmenu_folder)) {
        New-Item $scoop_startmenu_folder -type Directory
    }
    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = "$target"
    $wsShell.Save()
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global) {
    $manifest.shortcuts | ?{ $_ -ne $null } | % {
        $name = $_.item(1)
        $shortcut = "$(shortcut_folder)\$name.lnk"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item $shortcut
        }
    }
}
