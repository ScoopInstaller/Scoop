# Usage: scoop config [rm] name [value]
# Summary: Get or set configuration values
# Help: The scoop configuration file is saved at ~/.config/scoop/config.json.
#
# To get all configuration settings:
#
#     scoop config
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
# use_external_7zip: $true|$false
#       External 7zip (from path) will be used for archives extraction.
#
# use_lessmsi: $true|$false
#       Prefer lessmsi utility over native msiexec.
#
# no_junction: $true|$false
#       The 'current' version alias will not be used. Shims and shortcuts will point to specific version instead.
#
# scoop_repo: http://github.com/ScoopInstaller/Scoop
#       Git repository containining scoop source code.
#       This configuration is useful for custom forks.
#
# scoop_branch: master|develop
#       Allow to use different branch than master.
#       Could be used for testing specific functionalities before released into all users.
#       If you want to receive updates earlier to test new functionalities use develop (see: 'https://github.com/ScoopInstaller/Scoop/issues/2939')
#
# proxy: [username:password@]host:port
#       By default, Scoop will use the proxy settings from Internet Options, but with anonymous authentication.
#
#       * To use the credentials for the current logged-in user, use 'currentuser' in place of username:password
#       * To use the system proxy settings configured in Internet Options, use 'default' in place of host:port
#       * An empty or unset value for proxy is equivalent to 'default' (with no username or password)
#       * To bypass the system proxy and connect directly, use 'none' (with no username or password)
#
# autostash_on_conflict: $true|$false
#       When a conflict is detected during updating, Scoop will auto-stash the uncommitted changes.
#       (Default is $false, which will abort the update)
#
# default_architecture: 64bit|32bit|arm64
#       Allow to configure preferred architecture for application installation.
#       If not specified, architecture is determined be system.
#
# debug: $true|$false
#       Additional and detailed output will be shown.
#
# force_update: $true|$false
#       Force apps updating to bucket's version.
#
# show_update_log: $true|$false
#       Do not show changed commits on 'scoop update'
#
# show_manifest: $true|$false
#       Displays the manifest of every app that's about to
#       be installed, then asks user if they wish to proceed.
#
# shim: kiennq|scoopcs|71
#       Choose scoop shim build.
#
# root_path: $Env:UserProfile\scoop
#       Path to Scoop root directory.
#
# global_path: $Env:ProgramData\scoop
#       Path to Scoop root directory for global apps.
#
# cache_path:
#       For downloads, defaults to 'cache' folder under Scoop root directory.
#
# gh_token:
#       GitHub API token used to make authenticated requests.
#       This is essential for checkver and similar functions to run without
#       incurring rate limits and download from private repositories.
#
# virustotal_api_key:
#       API key used for uploading/scanning files using virustotal.
#       See: 'https://support.virustotal.com/hc/en-us/articles/115002088769-Please-give-me-an-API-key'
#
# cat_style:
#       When set to a non-empty string, Scoop will use 'bat' to display the manifest for
#       the `scoop cat` command and while doing manifest review. This requires 'bat' to be
#       installed (run `scoop install bat` to install it), otherwise errors will be thrown.
#       The accepted values are the same as ones passed to the --style flag of 'bat'.
#
# ignore_running_processes: $true|$false
#       When set to $false (default), Scoop would stop its procedure immediately if it detects
#       any target app process is running. Procedure here refers to reset/uninstall/update.
#       When set to $true, Scoop only displays a warning message and continues procedure.
#
# private_hosts:
#       Array of private hosts that need additional authentication.
#       For example, if you want to access a private GitHub repository,
#       you need to add the host to this list with 'match' and 'headers' strings.
#
# hold_update_until:
#       Disable/Hold Scoop self-updates, until the specified date.
#       `scoop hold scoop` will set the value to one day later.
#       Should be in the format 'YYYY-MM-DD', 'YYYY/MM/DD' or any other forms that accepted by '[System.DateTime]::Parse()'.
#       Ref: https://docs.microsoft.com/dotnet/api/system.datetime.parse?view=netframework-4.5#StringToParse
#
# ARIA2 configuration
# -------------------
#
# aria2-enabled: $true|$false
#       Aria2c will be used for downloading of artifacts.
#
# aria2-warning-enabled: $true|$false
#       Disable Aria2c warning which is shown while downloading.
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

if (!$name) {
    $scoopConfig
} elseif ($name -like '--help') {
    my_usage
} elseif ($name -like 'rm') {
    # NOTE Scoop config file migration. Remove this after 2023/6/30
    if ($value -notin 'SCOOP_REPO', 'SCOOP_BRANCH' -and $value -in $newConfigNames.Keys) {
        warn ('Config option "{0}" is deprecated, please use "{1}" instead next time.' -f $value, $newConfigNames.$value)
        $value = $newConfigNames.$value
    }
    # END NOTE
    set_config $value $null | Out-Null
    Write-Host "'$value' has been removed"
} elseif ($null -ne $value) {
    # NOTE Scoop config file migration. Remove this after 2023/6/30
    if ($name -notin 'SCOOP_REPO', 'SCOOP_BRANCH' -and $name -in $newConfigNames.Keys) {
        warn ('Config option "{0}" is deprecated, please use "{1}" instead next time.' -f $name, $newConfigNames.$name)
        $name = $newConfigNames.$name
    }
    # END NOTE
    set_config $name $value | Out-Null
    Write-Host "'$name' has been set to '$value'"
} else {
    # NOTE Scoop config file migration. Remove this after 2023/6/30
    if ($name -notin 'SCOOP_REPO', 'SCOOP_BRANCH' -and $name -in $newConfigNames.Keys) {
        warn ('Config option "{0}" is deprecated, please use "{1}" instead next time.' -f $name, $newConfigNames.$name)
        $name = $newConfigNames.$name
    }
    # END NOTE
    $value = get_config $name
    if($null -eq $value) {
        Write-Host "'$name' is not set"
    } else {
        $value
    }
}

exit 0
