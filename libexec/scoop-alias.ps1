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
#     scoop alias add rm 'scoop uninstall $args[0]' "Uninstalls an app"

param($opt, $name, $command, $description)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\install.ps1"

$script:config_alias = "alias"

function init_alias_config {
  $aliases = get_config $script:config_alias
  if(!$aliases) {
    $aliases = @{}
  }

  $aliases
}

function add_alias($name, $command) {
  if(!$command) {
    abort "Can't create an empty alias."
  }

  # get current aliases from config
  $aliases = init_alias_config
  if($aliases.containskey($name)) {
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
  $aliases += @{ $name = $alias_file }
  set_config $script:config_alias $aliases
}

function rm_alias($name) {
  $aliases = init_alias_config
  if(!$name) {
    abort "Which alias should be removed?"
  }

  if($aliases.containskey($name)) {
    "Removing alias $name..."

    rm_shim $aliases.get_item($name) (shimdir $false)

    $aliases.remove($name)
    set_config $script:config_alias $aliases
  }
  else { abort "Alias $name doesn't exist." }
}

function list_aliases {
  $aliases = @{}

  (init_alias_config).getenumerator() |% {
    $summary = summary (gc (command_path $_.name) -raw)
    if(!($summary)) { $summary = '' }
    $aliases.add("$($_.name) ", $summary)
  }

  if(!$aliases.count) {
    warn "No aliases founds."
  }

  $aliases.getenumerator() | sort name | ft -hidetablehead -autosize -wrap
}

switch($opt) {
  "add" { add_alias $name $command }
  "rm" { rm_alias $name }
  "list" { list_aliases }
  default { my_usage; exit 1 }
}

exit 0
