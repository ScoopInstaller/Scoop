function get_aliases_from_config {
    get_config ALIAS ([PSCustomObject]@{})
}

function add_alias {
    param(
        [ValidateNotNullOrEmpty()]
        [string]$name,
        [ValidateNotNullOrEmpty()]
        [string]$command,
        [string]$description
    )

    $aliases = get_aliases_from_config
    if ($aliases.$name) {
        abort "Alias '$name' already exists."
    }

    $alias_script_name = "scoop-$name"
    $shimdir = shimdir $false
    if (Test-Path "$shimdir\$alias_script_name.ps1") {
        abort "File '$alias_script_name.ps1' already exists in shims directory."
    }
    $script = @(
        "# Summary:$(if ($description) { " $description" })",
        "$command"
    )
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

    $aliases = get_aliases_from_config
    if (!$aliases.$name) {
        abort "Alias '$name' doesn't exist."
    }

    info "Removing alias '$name'..."
    rm_shim $aliases.$name (shimdir $false)
    $aliases.PSObject.Properties.Remove($name)
    set_config ALIAS $aliases | Out-Null
    return
}

function list_aliases {
    param([bool]$verbose)

    $aliases = get_aliases_from_config
    $alias_info = $aliases.PSObject.Properties.Name | ForEach-Object {
        $content = Get-Content (command_path $_)
        @{
            Name    = $_
            Summary = (summary $content).Trim()
            Command = ($content | Select-Object -Skip 1).Trim()
        }
    }
    if (!$alias_info) {
        info "No alias found."
        return
    }
    $alias_info = $alias_info | Sort-Object Name
    $properties = @('Name', 'Command')
    if ($verbose) {
        $properties += 'Summary'
    }
    $alias_info | Select-Object $properties
}
