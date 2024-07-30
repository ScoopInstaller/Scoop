# Usage: scoop alias <subcommand> [options] [<args>]
# Summary: Manage scoop aliases
# Help: Available subcommands: add, rm, list.
#
# Aliases are custom Scoop subcommands that can be created to make common tasks easier.
#
# To add an alias:
#
#     scoop alias add <name> <command> [<description>]
#
# e.g.,
#
#     scoop alias add rm 'scoop uninstall $args[0]' 'Uninstall an app'
#     scoop alias add upgrade 'scoop update *' 'Update all apps, just like "brew" or "apt"'
#
# To remove an alias:
#
#     scoop alias rm <name>
#
# To list all aliases:
#
#     scoop alias list [-v|--verbose]
#
# Options:
#   -v, --verbose  Show alias description and table headers (works only for "list")

param($SubCommand)

. "$PSScriptRoot\..\lib\getopt.ps1"

$SubCommands = @('add', 'rm', 'list')
if ($SubCommand -notin $SubCommands) {
    if (!$SubCommand) {
        error '<subcommand> missing'
    } else {
        error "'$SubCommand' is not one of available subcommands: $($SubCommands -join ', ')"
    }
    my_usage
    exit 1
}

$opt, $other, $err = getopt $Args 'v' 'verbose'
if ($err) { "scoop alias: $err"; exit 1 }

$name, $command, $description = $other
$verbose = $opt.v -or $opt.verbose

switch ($SubCommand) {
    'add' {
        if (!$name -or !$command) {
            error "<name> and <command> must be specified for subcommand 'add'"
            exit 1
        }
        add_alias $name $command $description
    }
    'rm' {
        if (!$name) {
            error "<name> must be specified for subcommand 'rm'"
            exit 1
        }
        rm_alias $name
    }
    'list' {
        list_aliases $verbose
    }
}

exit 0
