# Usage: scoop alias add|list|rm [<args>]
# Summary: Manage scoop aliases
# Help: Add, remove or list Scoop aliases
#
# Aliases are custom Scoop subcommands that can be created to make common tasks
# easier.
#
# To add an Alias:
#     scoop alias add <name> <command> <description>
#
# e.g.:
#     scoop alias add rm 'scoop uninstall $args[0]' 'Uninstalls an app'
#     scoop alias add upgrade 'scoop update *' 'Updates all apps, just like brew or apt'
#
# Options:
#   -v, --verbose   Show alias description and table headers (works only for 'list')

param(
  [String]$opt,
  [String]$name,
  [String]$command,
  [String]$description,
  [Switch]$verbose = $false
)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\install.ps1"

$script:config_alias = "alias"

function init_alias_config {
    $aliases = get_config $script:config_alias
    if(!$aliases) {
        $aliases = @{}
    }

    return $aliases
}

function add_alias($name, $command) {
    if(!$command) {
        abort "Can't create an empty alias."
    }

    # get current aliases from config
    $aliases = init_alias_config
    if($aliases.$name) {
        abort "Alias $name already exists."
    }

    $alias_file = "scoop-$name"

    # generate script
    $shimdir = shimdir $false
    $script =
@"
# Summary: $description
$command
"@
    $script | out-file "$shimdir\$alias_file.ps1" -encoding utf8

    # add alias to config
    $aliases | Add-Member -MemberType NoteProperty -Name $name -Value $alias_file

    set_config $script:config_alias $aliases | Out-Null
}

function rm_alias($name) {
    $aliases = init_alias_config
    if(!$name) {
        abort "Which alias should be removed?"
    }

    if($aliases.$name) {
        "Removing alias $name..."

        rm_shim $aliases.$name (shimdir $false)

        $aliases.PSObject.Properties.Remove($name)
        set_config $script:config_alias $aliases | Out-Null
    } else {
        abort "Alias $name doesn't exist."
    }
}

function list_aliases {
    $aliases = @()

    (init_alias_config).PSObject.Properties.GetEnumerator() | ForEach-Object {
        $content = Get-Content (command_path $_.Name)
        $command = ($content | Select-Object -Skip 1).Trim()
        $summary = (summary $content).Trim()

        $aliases += New-Object psobject -Property @{Name=$_.name; Summary=$summary; Command=$command}
    }

    if(!$aliases.count) {
        warn "No aliases founds."
    }
    $aliases = $aliases.GetEnumerator() | Sort-Object Name
    if($verbose) {
        return $aliases | Select-Object Name, Command, Summary | Format-Table -autosize -wrap
    } else {
        return $aliases | Select-Object Name, Command | Format-Table -autosize -hidetablehead -wrap
    }
}

switch($opt) {
    "add" { add_alias $name $command }
    "rm" { rm_alias $name }
    "list" { list_aliases }
    default { my_usage; exit 1 }
}

exit 0
