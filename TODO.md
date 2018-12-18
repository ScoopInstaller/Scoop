# Add support for yml typed manifests

- [ ] Blocked by <https://github.com/cloudbase/powershell-yaml/issues/38>
- [x] .vscode settings
- [x] Submodule
- [x] `parse_json` -> `Scoop-ParseManifest { if (json) { _parseJson } else {_parseYaml} }`
- [x] url_manifest function
- [ ] ConvertTo-Yaml is converting `|` to `>` (See: <https://github.com/cloudbase/powershell-yaml/issues/40>)
- [ ] Binaries
    - [x] autoupdate function call
    - [ ] auto-pr
        - [ ] Inspect TODOs
    - [x] checkurls
    - [x] checkver
        - [x] Fix noteproperty
    - [x] describe
    - [x] formatjson
    - [x] format
    - [x] missing-checkver
    - [x] test
- [ ] Commands
    - [x] install.ps1
- [ ] Remote install yaml
- [ ] Tests
    - [ ] Validate yaml
- [ ] `bin\*`
    - [ ] Import Yaml module
- [ ] `Scoop-Format-Manifest.Tests.ps1` -> `Scoop-Format-Manifest.json.Tests.ps1`
- [ ] `Scoop-Format-Manifest.yml.Tests.ps1`
- [ ] `ConvertToPrettyYaml` ❓❓
    - [ ] Indent arrays with 2 spaces
    - [ ] Convert `>` to `|` (workarround)

# Local testing

Predefined docker for adequate testing.

1. [ ] Make sure implementation work same for json and yaml.
1. [ ] Commands
    1. [ ] Installing
        1. [ ] Bucket folder
            - `scoop install yamBoth` and `scoop install yamApache` should produce same output
            - `scoop install yamOne` and `scoop install yamFaas` should produce same output
            - `scoop install yamURL` and `scoop install yamAhoy` should produce same output
            - `scoop install yamMultipleURL` and `scoop install yamCoreutils` should produce same output
            - Same output meaning:
                - `manifest.json`
                - persisted files
                - shortcuts
        1. [ ] Remote
        1. [ ] Local relative / full path
    1. [ ] Uninstalling (See installing)
        1. [ ] Bucket folder
        1. [ ] Remote
        1. [ ] Local relative / full file
    1. [ ] Info
    1. [ ] Reset
    1. [ ] Update
        1. [ ] Normal
        1. [ ] Force
        1. [ ] JSON converted to yaml
            1. [ ] Normal
            1. [ ] Force
1. [ ] Binaries which write /edit manifests
    1. [ ] checkver
    1. [ ] auto-pr

# After Review; Before Merging changes

Maybe we could keep Docker related files? For easier debugging of core functions?

1. [ ] Delete
    1. [ ] TODO.md
    1. [ ] Nested yamTEST bucket folder
    1. [ ] docker-compose.yml
    1. [ ] Dockerfile
1. [ ] Cleanup debug information
