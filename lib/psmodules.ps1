$modulesdir = "$scoopdir\modules"

function install_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if(!$psmodule) { return }

    if($global) {
        abort "global installs for powershell modules is not implemented!"
    }

    $modulesdir = ensure $modulesdir
    ensure_in_psmodulepath $modulesdir $global

    $module_name = $psmodule.name
    if(!$module_name) {
        abort "invalid manifest: the 'name' property is missing from 'psmodule'"
        return
    }

    $linkfrom = "$modulesdir\$module_name"
    write-host "installing PowerShell module '$module_name'"

    write-host "linking $(friendly_path $linkfrom) => $(friendly_path $dir)"

    if(test-path $linkfrom) {
        warn "$(friendly_path $linkfrom) already exists: will be replaced"
        cmd /c rmdir $linkfrom
    }

    cmd /c mklink /j $linkfrom $dir | out-null
}

function uninstall_psmodule($manifest, $dir, $global) {
    $psmodule = $manifest.psmodule
    if(!$psmodule) { return }

    $module_name = $psmodule.name
    write-host "uninstalling PowerShell module '$module_name'"

    $linkfrom = "$modulesdir\$module_name"
    if(test-path $linkfrom) {
        write-host "removing $(friendly_path $linkfrom)"
        $linkfrom = resolve-path $linkfrom
        cmd /c rmdir $linkfrom
    }
}

function ensure_in_psmodulepath($dir, $global) {
    $path = env 'psmodulepath' $global
    $dir = fullpath $dir
    if($path -notmatch [regex]::escape($dir)) {
        echo "adding $(friendly_path $dir) to $(if($global){'global'}else{'your'}) PowerShell module path"

        env 'psmodulepath' $global "$dir;$path" # for future sessions...
        $env:psmodulepath = "$dir;$env:psmodulepath" # for this session
    }
}
