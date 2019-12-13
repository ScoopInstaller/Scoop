# Usage: scoop config [rm] name [value]
# Summary: Get or set configuration values
# Help: The scoop configuration file is saved at ~/.config/scoop/config.json.
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
# proxy: [username:password@]host:port
#       By default, Scoop will use the proxy settings from Internet Options, but with anonymous authentication.
#
#       * To use the credentials for the current logged-in user, use 'currentuser' in place of username:password
#       * To use the system proxy settings configured in Internet Options, use 'default' in place of host:port
#       * An empty or unset value for proxy is equivalent to 'default' (with no username or password)
#       * To bypass the system proxy and connect directly, use 'none' (with no username or password)
#
# default-architecture: 64bit|32bit
#       Allow to configure preferred architecture for application installation.
#       If not specified, architecture is determined be system.
#
# 7ZIPEXTRACT_USE_EXTERNAL: $true|$false
#       External 7zip (from path) will be used for archives extraction.
#
# MSIEXTRACT_USE_LESSMSI: $true|$false
#       Prefer lessmsi utility over native msiexec.
#
# NO_JUNCTIONS: $true|$false
#       The 'Current' version alias will not be used. Shims and shortcuts will point to specifc version instad.
#
# debug: $true|$false
#       Additional and detailed output will be shown.
#
# SCOOP_REPO: http://github.com/lukesampson/scoop
#       Git repository containining scoop source code.
#       This configuration is useful for custom tweaked forks.
#
# SCOOP_BRANCH: master|develop
#       Allow to use different branch than master.
#       Could be used for testing specific functionalities before released into all users.
#       If you want to receive updates earlier to test new functionalities use develop (see: 'https://github.com/lukesampson/scoop/issues/2939')
#
# show_update_log: $true|$false
#       Do not show changed commits on 'scoop update'
#
# virustotal_api_key:
#       API key used for uploading/scanning files using virustotal.
#       See: 'https://support.virustotal.com/hc/en-us/articles/115002088769-Please-give-me-an-API-key'
#
# ARIA2 configuration
# -------------------
#
# aria2-enabled: $true|$false
#       Aria2c will be used for downloading of artifacts.
#
# aria2-retry-wait: 2
#       Number of seconds to wait between retries.
#       See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-retry-wait'
#
# aria2-split: 5
#       Number of connections used for downlaod.
#       See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-s'
#
# aria2-max-connection-per-server: 5
#       The maximum number of connections to one server for each download.
#       See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-x'
#
# aria2-min-split-size: 5M
#       Downloaded files will be splitted by this configured size and downloaded using multiple connections.
#       See: 'https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-k'
#
# aria2-options:
#       Array of additional aria2 options.
#       See: 'https://aria2.github.io/manual/en/html/aria2c.html#options'

param($name, $value)

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\help.ps1"

reset_aliases

if(!$name) { my_usage; exit 1 }

if($name -like 'rm') {
    set_config $value $null | Out-Null
    Write-Output "'$value' has been removed"
} elseif($null -ne $value) {
    set_config $name $value | Out-Null
    Write-Output "'$name' has been set to '$value'"
} else {
    $value = get_config $name
    if($null -eq $value) {
        Write-Output "'$name' is not set"
    } else {
        Write-Output $value
    }
}

exit 0
