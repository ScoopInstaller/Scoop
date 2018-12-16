# Add support for yml typed manifests

- [ ] Blocked by <https://github.com/cloudbase/powershell-yaml/issues/38>
- [x] .vscode settings
- [x] Submodule
- [ ] `parse_json` -> `Scoop-ParseManifest { if (json) { _parseJson } else {_parseYaml} }`
- [ ] ConvertTo-Yaml is converting `|` to `>`
- [ ] url_manifest function
- [ ] Binaries
    - [ ] auto-pr
        - [ ] Inspect TODOs
    - [ ] checkver
        - [ ] fix noteproperty
    - [ ] autoupdate function call
- [ ] Download progress is not showing
- [ ] Commands
    - [ ] install.ps1
        - [ ] `Copy-Item (manifest_path $app $bucket) "$dir\manifest.json"` -> `(parse_manifest (manifest_path $app $bucket))`
- [ ] Remote install yaml
- [ ] Tests
  - [ ] Validate yaml
- [ ] `bin\*`
    - [ ] Import Yaml module
- [ ] `Scoop-Format-Manifest.Tests.ps1` -> `Scoop-Format-Manifest.json.Tests.ps1`
- [ ] `Scoop-Format-Manifest.yml.Tests.ps1`

# Local testing

Create bucket YAMLs in `$env:SCOOP\buckets`. Keep only few manifests prefixed with yam (to make sure non of them exists in main):

1. [ ] Make sure implementation work same for json and yaml.
1. [ ] Commands
    1. [ ] Installing
        1. [ ] Remote
        1. [ ] apacheyaml
        1. [ ] Bucket folder
        1. [ ] Local full path
    1. [ ] Uninstalling
        1. [ ] Remote
        1. [ ] Bucket folder
        1. [ ] Local relative file
    1. [ ] Info
    1. [ ] Reset
    1. [ ] Update
        1. [ ] Normal
        1. [ ] Force
        1. [ ] JSON converted to yaml
            1. [ ] Normal
            1. [ ] Force
1. [ ] Binaries
    1. [ ] checkver
    1. [ ] auto-pr

# After Review; Before Merging changes

1. [ ] Delete
   1. [ ] TODO.md
   1. [ ] Nested bucket folder
   1. [ ] docker-compose.yml
