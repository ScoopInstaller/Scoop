# Usage: scoop fix [<args>]
# Summary: Fix moved apps
# Help: Try to fix unusable apps problem caused by missing junction points
# and/or shims.
# 
# By default this command checks and tries to fix those apps missing
# junction points and/or shims.
#
# To check and fix only specific apps:
#     scoop fix <app> [<app2>, <app3>...]

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\shortcuts.ps1"
. "$psscriptroot\..\lib\versions.ps1"

reset_aliases

# functions
function MULTIPLE_AND() {
    Process {
        & $ExecutionContext.InvokeCommand.NewScriptBlock(
            $_ -join ' -and ' -replace("($true)|($false)",'("\1" -eq $true)')
        )
    }
}
function I($OUTER_ARGS = $ARGS) {
    # function to be executed inside a scriptblock to process $args
    # for passing them to nested child scriptblock
    ,@( foreach($i in 0..$($OUTER_ARGS.count - 1)) {
            if($OUTER_ARGS[$i][0] -is [scriptblock]) {
                $OUTER_ARGS[$i][0]
            } else {
                $OUTER_ARGS[$i]
            }
        }
    )
}

# functions to get currently existed fine items; output as a manifest filter
function current_alias($app, $global) { Get-ItemProperty $(versiondir $app 'current' $global) | Select -ExpandProperty 'Target' }
function current_persist($app, $global) {
    $version = current_version $app $global
    $versiondir = versiondir $app $version $global
    $manifest = installed_manifest $app $version $global

    if($manifest.persist) {
        $manifest.persist | ForEach-Object {
            if(Test-Path $versiondir\$_) {
                Get-ItemProperty "$versiondir\$_" |
                ForEach-Object {
                    if($_.LinkType) {
                        $_.Target.replace("$versiondir","")
                    }
                }
            }
        }
    }
}
function current_shim($app, $global) {
    $shimdir = ensure (shimdir $global)
    $version = current_version $app $global
    $manifest = installed_manifest $app $version $global

    $manifestShim = @(arch_specific 'bin' $manifest $arch)
    if($manifestShim) {
        $manifestShim | ForEach-Object {
            $fname_ = $(fname $_[0]).tolower()
            $shimname_ = if(!$_[1]) { strip_ext $fname_ } else { $_[1] }

            $pathInquotes = { '''([^*?|<>"]+(((?=")(?<="))|((?='''')(?<='''')))' + "$fname_$_[1][$ARGS]`)'" }

            & {
                { $ExecutionContext.InvokeCommand.NewScriptBlock(
                    ' $shimContent_' + "$($ARGS[0] -replace(""^(?=.)"",""["") -replace(""`$(?<=.)"",""]""))" +
                    ' | ForEach-Object { $_ ' + "$($ARGS[1] -replace(""^(?=.)"",""-match '"")
                                                                -replace(""`$(?<=.)"",""'""))" +
                    '                       -match((. $pathInquotes $ARGS)) } 
                      | ForEach-Object { $_ | Resolve-Path -Path @($matches.values)[-1] | Test-Path }'
                  )
                } | ForEach-Object {
                @(
                  @('\.exe$', @('.exe','.shim'),
                    @({ $true },
                      { Resolve-Path -Path $(($shimContent_ -split('\s*=\s*'))[1] | Test-Path)})),
                  @('\.((bat)|(cmd))$', @('.cmd',''),
                    @((& $_   ),
                      (& $_ 1 ))),
                  @('\.ps1$', @('','.cmd'),
                    @((& $_ 1 ),
                      (& $_ $null 'powershell'))),
                  @('\.jar$', @('','.cmd'),
                    @((& $_ 1 ),
                      (& $_   )))
                )}|
                ForEach-Object {
                $_[1] += '.ps1'
                $_[2] += { ( $shimContent_[0].tolower() -match
                               ( '\$path\s*=\s*join-path\s+"\$psscriptroot"\s+' + """.+$fname_""$" )) -and
                           ( & $ExecutionContext.InvokeCommand.NewScriptBlock(
                                 @($matches.values)[-1].replace('$psscriptroot',$shimdir)
                                                            -replace('^\$path\s*=\s*','')) | Resolve-Path | Test-Path)
                         }
                $_
                } |
                ForEach-Object {
                    if($fname_ -match $_[0]) {
                        & {
                            if(& $ARGS[0][0] $ARGS[1][0]) {
                                if(& $ARGS[0][0] $ARGS[2][0] $ARGS[3][0]) {
                                    return $true
                                }
                            }
                            return $false
                        } {
                            ,@( foreach($i in 0..$_[1].indexOf($_[1][-1])) {
                                    & $ExecutionContext.InvokeCommand.NewScriptBlock(
                                        $ARGS -join '; &' -replace('^','&')
                                    )
                                }
                            ) | MULTIPLE_AND
                          } { Test-Path -Path "$shimdir\$shimname_$_[1][$i]" 
                            } { $shimContent_ = Get-Content -Path "$shimdir\$shimname_$_[1][$i]"
                              } { & $_[2][$i] $i }
                    }
                } |
                MULTIPLE_AND |
                & {
                    if($Input) {
                        return $ARGS[0]
                    }
                } (I)
            } $_
        }
    }
}
function current_shortcuts($app, $global) {
    $shortcut_folder = shortcut_folder $global
    $currentdir = versiondir $app 'current' $global
    $version = current_version $app $global
    $manifest = installed_manifest $app $version $global

    $manifestShortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    if($manifestShortcuts) {
        $manifestShortcuts | ForEach-Object {
            $shortcutpath_ = "$shortcut_folder\$($_[1]).lnk" | Resolve-Path
            $targetpath_ = "$currentdir\$($_[0])" | Resolve-Path
            $arguments_ = $_[2]
            $iconlocation = if($_[3]) { "$currentdir\$($_[3]),0" }

            ( ($shortcutpath_ | Test-Path) -and
              ( ((New-Object -ComObject WScript.Shell).CreateShortcut($shortcut_)) | ForEach-Object {
                    ($_.TargetPath -eq $targetpath_) -and
                    ($_.Arguments -eq $arguments_) -and
                    ($_.IconLocation -eq $iconlocation_)
                }
              )
            ) -and
            ( return $_ )
        }
    }
}

function check_app([HashTable] $apps, [HashTable] $broken = $broken) {
    & {
        $apps.GetEnumerator() | Sort-Object { $_.key } | & { Process {
            $app = $_.key
            $global = $_.value.isGlobal
            $version = current_version $app $global
            $manifest = installed_manifest $app $version $global

            $manifestAlias = versiondir $app $version $global
        
            $currentAlias = current_alias $app $global
            
            & $ARGS[0][0][0] ('Alias' | &{ Process{& $ARGS[0][1][0]}} (I))

            if($currentAlias -ne $manifestAlias) { return }
            # shim and shortcuts are targeted to app's 'current' alias dir,
            # only after alias has been fixed can they be checked.

            $manifestPersist = $manifest.persist

            $currentPersist = @(current_persist $app $global)
            $currentShim = @(current_shim $app $global)
            $currentShortcuts = @(current_shortcuts $app $global)

            'Persist', 'Shim', 'Shortcuts' | & { Process {
                & $ARGS[0][0][0] (& $ARGS[0][1][0])
            }} (I)
        }} (I)
    } {
        if(!($broken.$app)) {
            $broken[$app] = @{ 'isGlobal' = $global; 'version' = $version }
        }
        $broken[$app][$ARGS[0]] = Compare-Object -ReferenceObject $ARGS[1] -DifferenceObject $ARGS[2] |
                                         Where-Object { $_.SideIndicator -eq '<=' } |
                                         Select-Object -ExpandProperty 'InputObject'
      } { Write-Output $_ $(Get-Variable "manifest$_" -ValueOnly) $(Get-Variable "current$_" -ValueOnly) }
}

function whats_found_broken([HashTable] $broken = $broken) {
    [System.Collections.ArrayList]@(
        $broken.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{} |
            Select 'Name', 'Version', 'isGlobal', 'badAlias', 'badPersist', 'badShim', 'badShortcuts' | & { Process {
                $_.Name, $_.isGlobal, $_.badAlias, $_.badPersist, $_.badShim, $_.badShortcuts = $ARGS
            }} $_.key $_.value.version $_.value.isGlobal $_.value.Alias $_.value.Persist $_.value.Shim $_.value.Shortcuts
        }
    )
}

function fix($broken) {
    $broken.keys | ForEach-Object {
        $app = $_
        $global = $broken[$_].isGlobal

        $version = current_version $app $global
        info "Fixing '$app' ($version)"

        $manifest = installed_manifest $app $version $global
        $install_info = install_info $app $version $global

        $dir = versiondir $app $version $global
        $original_dir = $dir # keep reference to real (not linked) directory
        $persist_dir = persistdir $app $global

        try {
            test-path $dir -ea stop | out-null
        } catch [unauthorizedaccessexception] {
            error "Access denied: $dir. You might need to restart."
            return
        }

        if($broken[$_].Alias) {
            $dir = link_current $dir

            check_app $broken[$_]
        }

        $def_arch = default_architecture
        $architecture = $install_info.architecture

        if(($def_arch -eq '32bit') -and ($architecture -ne $def_arch)) {
            warn "'$app' ($version) is a $architecture app while current environment is $def_arch!"
        }

        if($broken[$_].Shims) {
            create_shims $manifest $dir $global $architecture
        }
        if($broken[$_].Shortcuts) {
            create_startmenu_shortcuts $manifest $dir $global $architecture
        }

        install_psmodule $manifest $dir $global
        env_add_path $manifest $dir $global
        env_set $manifest $dir $global

        if($broken[$_].Persist) {
            persist_data $manifest $original_dir $persist_dir
            persist_permission $manifest $global
        }

        $broken.remove($_)
        success "'$app' ($version) was fixed successfully!"
    }
}

# options
$opt, $specified, $err = getopt $args 'g' 'global'
if($err) {
    abort "scoop fix: $err"
}
$global = $opt.g -or $opt.global

$broken = @{}

if($global -and !(is_admin)) {
    abort 'ERROR: you need admin rights to fix global apps.'
}

,@( ( if($specified) {
          ensure_all_installed $specified $global
      } else {
          ,@($false, $true | ForEach-Object {
              & { installed_apps $_ | & { Process {
                      ,@($_, $ARGS[0])
                  } } (I)
              } $_
          })
      }
    ) | ForEach-Object {
        if($_) {
            $_.GetEnumerator().SyncRoot | ForEach-Object {
                @{ $_[0] = @{ 'isGlobal' = $_[1] }}
            }
        } else {
            abort "ERROR: There aren't any apps installed."
        }
    }
) | ForEach-Object {
    & $ExecutionContext.InvokeCommand.NewScriptBlock(
        $_ -join ' + '
    )
} | ForEach-Object {
    info "Finding broken apps$(if($specified) { `" in '$specified'`"})..."
    check_app $_
}

whats_found_broken

if($broken.scoop) {
    # get core functions
    $core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
    info 'Initializing...'
    Invoke-Expression (new-object net.webclient).downloadstring($core_url)

    $dir = ensure (versiondir 'scoop' 'current')

    # download scoop zip
    $zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
    $zipfile = "$dir\scoop.zip"
    info 'Downloading...'
    dl $zipurl $zipfile

    info 'Extracting...'
    unzip $zipfile "$dir\_tmp"
    Copy-Item "$dir\_tmp\scoop-master\*" $dir -r -force
    Remove-Item "$dir\_tmp" -r -force
    Remove-Item $zipfile

    info 'Creating shim...'
    shim "$dir\bin\scoop.ps1" $false

    ensure_robocopy_in_path
    ensure_scoop_in_path

    $broken.remove('scoop')
    success 'Scoop was fixed successfully!'
}

if(!$global) {
    $broken.keys | ForEach-Object {
        if($broken[$_].isGlobal) {
            $broken.remove($_)
        }
    }
}

if(is_scoop_outdated) {
    info 'Scoop is outdated and needs updating'
    if(installed 'git') {
        if($broken.git) {
            info 'Scoop uses Git to update itself but Git is broken now, trying to fix...'
            fix $broken.git
        }
    } else {
        info 'Scoop uses Git to update itself, installing Git...'
        scoop install git
    }
    scoop update
}

fix $broken
if($?) {
    success 'All completed successfully!'
}
