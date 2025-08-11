# Description: Functions for managing commands and aliases.

## Functions for commands

function command_files {
    (Get-ChildItem "$PSScriptRoot\..\libexec") + (Get-ChildItem "$scoopdir\shims") |
        Where-Object 'scoop-.*?\.ps1$' -Property Name -Match
}

function commands {
    command_files | ForEach-Object { command_name $_ }
}

function command_name($filename) {
    $filename.name | Select-String 'scoop-(.*?)\.ps1$' | ForEach-Object { $_.matches[0].groups[1].value }
}

function command_path($cmd) {
    $cmd_path = "$PSScriptRoot\..\libexec\scoop-$cmd.ps1"

    # built in commands
    if (!(Test-Path $cmd_path)) {
        # get path from shim
        $shim_path = "$scoopdir\shims\scoop-$cmd.ps1"
        $line = ((Get-Content $shim_path) | Where-Object { $_.startswith('$path') })
        if ($line) {
            Invoke-Command ([scriptblock]::Create($line)) -NoNewScope
            $cmd_path = $path
        } else { $cmd_path = $shim_path }
    }

    $cmd_path
}

function exec($cmd, $arguments) {
    $cmd_path = command_path $cmd

    & $cmd_path @arguments
}

## Functions for aliases

function add_alias {
    param(
        [ValidateNotNullOrEmpty()]
        [string]$name,
        [ValidateNotNullOrEmpty()]
        [string]$command,
        [string]$description
    )

    $aliases = get_config ALIAS ([PSCustomObject]@{})
    if ($aliases.$name) {
        abort "Alias '$name' already exists."
    }

    $alias_script_name = "scoop-$name"
    $shimdir = shimdir $false
    if (Test-Path "$shimdir\$alias_script_name.ps1") {
        abort "File '$alias_script_name.ps1' already exists in shims directory."
    }
    $script = @(
        "# Summary: $description",
        "$command"
    ) -join "`n"
    try {
        $script | Out-UTF8File "$shimdir\$alias_script_name.ps1"
    } catch {
        abort $_.Exception
    }

    # Add the new alias to the config.
    $aliases | Add-Member -MemberType NoteProperty -Name $name -Value $alias_script_name
    set_config ALIAS $aliases | Out-Null
}

function rm_alias {
    param(
        [ValidateNotNullOrEmpty()]
        [string]$name
    )

    $aliases = get_config ALIAS ([PSCustomObject]@{})
    if (!$aliases.$name) {
        abort "Alias '$name' doesn't exist."
    }

    info "Removing alias '$name'..."
    Remove-Item "$(shimdir $false)\scoop-$name.ps1"
    $aliases.PSObject.Properties.Remove($name)
    set_config ALIAS $aliases | Out-Null
}

function list_aliases {
    param(
        [bool]$verbose
    )

    $aliases = get_config ALIAS ([PSCustomObject]@{})
    $alias_info = $aliases.PSObject.Properties.Name | Where-Object { $_ } | ForEach-Object {
        $content = Get-Content (command_path $_)
        [PSCustomObject]@{
            Name    = $_
            Summary = (summary $content).Trim()
            Command = ($content | Select-Object -Skip 1).Trim()
        }
    }
    if (!$alias_info) {
        info 'No alias found.'
        return
    }
    $alias_info = $alias_info | Sort-Object Name
    $properties = @('Name', 'Command')
    if ($verbose) {
        $properties += 'Summary'
    }
    $alias_info | Select-Object $properties
}
