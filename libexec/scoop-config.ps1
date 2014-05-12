# Usage: scoop config [rm] name [value]
# Summary: Get or set configuration values
# Help: The scoop configuration file is saved at ~/.scoop.
#
# To get a configuration setting:
#
#     scoop config <name>
#
# To set a configuration setting:
#
#     scoop config <name> <value>
#
# To remove a configuration setting:     
#
#     scoop config rm <name>
#
# Settings
# --------
#
# proxy = username:password@host:port
param($name, $value)

. "$psscriptroot\..\lib\config.ps1"
. "$psscriptroot\..\lib\help.ps1"

if(!$name) { my_usage; exit 1 }

if($name -like 'rm') {
	set_config $value $null
} elseif($value) {
	set_config $name $value
} else {
	get_config $name $value
}