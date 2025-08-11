## [v0.5.2](https://github.com/ScoopInstaller/Scoop/compare/v0.5.1...v0.5.2) - 2024-07-26

### Bug Fixes

- **scoop-alias:** Fix 'Option --verbose not recognized.' ([#6062](https://github.com/ScoopInstaller/Scoop/issues/6062))
- **scoop-hold:** Use 'foreach' loop to allow 'continue' statement ([#6078](https://github.com/ScoopInstaller/Scoop/issues/6078))
- **core:** Use 'Join-Path' to construct cache file path ([#6079](https://github.com/ScoopInstaller/Scoop/issues/6079))
- **json:** Don't serialize jsonpath return if only one result ([#6066](https://github.com/ScoopInstaller/Scoop/issues/6066), [#6073](https://github.com/ScoopInstaller/Scoop/issues/6073))

### Builds

- **supporting:** Update Json.Schema to 4.0.1 ([#6072](https://github.com/ScoopInstaller/Scoop/issues/6072))

## [v0.5.1](https://github.com/ScoopInstaller/Scoop/compare/v0.5.0...v0.5.1) - 2024-07-16

### Bug Fixes

- **scoop-alias:** Pass options correctly ([#6003](https://github.com/ScoopInstaller/Scoop/issues/6003))
- **scoop-virustotal:** Adjust `json_path` parameters to retrieve correct analysis stats ([#6044](https://github.com/ScoopInstaller/Scoop/issues/6044))
- **bucket:** Implement error handling for failed bucket addition ([#6051](https://github.com/ScoopInstaller/Scoop/issues/6051))
- **database:** Fix compatibility with Windows PowerShell ([#6045](https://github.com/ScoopInstaller/Scoop/issues/6045))
- **install:** Expand `env_set` items before setting Environment Variables ([#6050](https://github.com/ScoopInstaller/Scoop/issues/6050))
- **install:** Fix parsing error when installing multiple apps w/ specific version ([#6039](https://github.com/ScoopInstaller/Scoop/issues/6039))

## [v0.5.0](https://github.com/ScoopInstaller/Scoop/compare/v0.4.2...v0.5.0) - 2024-07-01

### Features

- **scoop-search:** Use SQLite for caching apps to speed up local search ([#5851](https://github.com/ScoopInstaller/Scoop/issues/5851), [#5918](https://github.com/ScoopInstaller/Scoop/issues/5918), [#5946](https://github.com/ScoopInstaller/Scoop/issues/5946), [#5949](https://github.com/ScoopInstaller/Scoop/issues/5949), [#5955](https://github.com/ScoopInstaller/Scoop/issues/5955), [#5966](https://github.com/ScoopInstaller/Scoop/issues/5966), [#5967](https://github.com/ScoopInstaller/Scoop/issues/5967), [#5981](https://github.com/ScoopInstaller/Scoop/issues/5981))
- **core:** New cache filename format ([#5929](https://github.com/ScoopInstaller/Scoop/issues/5929), [#5944](https://github.com/ScoopInstaller/Scoop/issues/5944))
- **decompress:** Use innounp-unicode as default Inno Setup Unpacker ([#6028](https://github.com/ScoopInstaller/Scoop/issues/6028))
- **install:** Added the ability to install specific version of app from URL/file link ([#5988](https://github.com/ScoopInstaller/Scoop/issues/5988))

### Bug Fixes

- **scoop-download|install|update:** Use consistent options ([#5956](https://github.com/ScoopInstaller/Scoop/issues/5956))
- **scoop-info:** Fix download size estimating ([#5958](https://github.com/ScoopInstaller/Scoop/issues/5958))
- **scoop-search:** Catch error of parsing invalid manifest ([#5930](https://github.com/ScoopInstaller/Scoop/issues/5930))
- **checkver:** Correct variable 'regex' to 'regexp' ([#5993](https://github.com/ScoopInstaller/Scoop/issues/5993))
- **checkver:** Correct error messages ([#6024](https://github.com/ScoopInstaller/Scoop/issues/6024))
- **core:** Search for Git executable instead of any cmdlet ([#5998](https://github.com/ScoopInstaller/Scoop/issues/5998))
- **core:** Use correct path in 'bash' ([#6006](https://github.com/ScoopInstaller/Scoop/issues/6006))
- **core:** Limit the number of commands to get when search for git executable ([#6013](https://github.com/ScoopInstaller/Scoop/pull/6013))
- **decompress:** Match `extract_dir`/`extract_to` and archives ([#5983](https://github.com/ScoopInstaller/Scoop/issues/5983))
- **json:** Serialize jsonpath return ([#5921](https://github.com/ScoopInstaller/Scoop/issues/5921))
- **shim:** Restore original path for JAR cmd ([#6030](https://github.com/ScoopInstaller/Scoop/issues/6030))

### Code Refactoring

- **decompress:** Use 7zip to extract Zstd archive ([#5973](https://github.com/ScoopInstaller/Scoop/issues/5973))
- **install:** Separate archive extraction from downloader ([#5951](https://github.com/ScoopInstaller/Scoop/issues/5951))
- **install:** Replace 'run_(un)installer()' with 'Invoke-Installer()' ([#5968](https://github.com/ScoopInstaller/Scoop/issues/5968), [#5971](https://github.com/ScoopInstaller/Scoop/issues/5971))

## [v0.4.2](https://github.com/ScoopInstaller/Scoop/compare/v0.4.1...v0.4.2) - 2024-05-14

### Bug Fixes

- **autoupdate:** Copy `PSCustomObject`-type properties within `substitute()` to prevent reference changes ([#5934](https://github.com/ScoopInstaller/Scoop/issues/5934), [#5962](https://github.com/ScoopInstaller/Scoop/issues/5962))
- **core:** Fix `Invoke-ExternalCommand` quoting rules ([#5945](https://github.com/ScoopInstaller/Scoop/issues/5945))
- **system:** Fix argument passing to `Split-PathLikeEnvVar()` in deprecated `strip_path()` ([#5937](https://github.com/ScoopInstaller/Scoop/issues/5937))

## [v0.4.1](https://github.com/ScoopInstaller/Scoop/compare/v0.4.0...v0.4.1) - 2024-04-25

### Bug Fixes

- **core:** Fix `Invoke-ExternalCommand` regression ([#5923](https://github.com/ScoopInstaller/Scoop/issues/5923))

## [v0.4.0](https://github.com/ScoopInstaller/Scoop/compare/v0.3.1...v0.4.0) - 2024-04-18

### Features

- **scoop-update:** Add support for parallel syncing buckets in PowerShell 7 and improve output ([#5122](https://github.com/ScoopInstaller/Scoop/issues/5122))
- **bucket:** Switch nirsoft bucket to ScoopInstaller/Nirsoft ([#5328](https://github.com/ScoopInstaller/Scoop/issues/5328))
- **bucket:** Make official buckets higher priority ([#5398](https://github.com/ScoopInstaller/Scoop/issues/5398))
- **config:** Support portable config file ([#5369](https://github.com/ScoopInstaller/Scoop/issues/5369))
- **core:** Add `-Quiet` switch for `Invoke-ExternalCommand` ([#5346](https://github.com/ScoopInstaller/Scoop/issues/5346))
- **core:** Allow global install of PowerShell modules ([#5611](https://github.com/ScoopInstaller/Scoop/issues/5611))
- **path:** Isolate Scoop apps' PATH ([#5840](https://github.com/ScoopInstaller/Scoop/issues/5840))

### Bug Fixes

- **scoop-alias:** Prevent overwrite existing file when adding alias ([#5577](https://github.com/ScoopInstaller/Scoop/issues/5577))
- **scoop-checkup:** Skip defender check in Windows Sandbox ([#5519](https://github.com/ScoopInstaller/Scoop/issues/5519))
- **scoop-checkup:** Change the message level of helpers from ERROR to WARN ([#5614](https://github.com/ScoopInstaller/Scoop/issues/5614))
- **scoop-checkup:** Don't throw 7zip error when external 7zip is used ([#5703](https://github.com/ScoopInstaller/Scoop/issues/5703))
- **scoop-(un)hold:** Correct output the messages when manifest not found, (already|not) held ([#5519](https://github.com/ScoopInstaller/Scoop/issues/5519))
- **scoop-info:** Fix errors in file size collection when `--verbose` ([#5352](https://github.com/ScoopInstaller/Scoop/issues/5352))
- **scoop-reset:** Don't abort when multiple apps are passed and an app is running ([#5687](https://github.com/ScoopInstaller/Scoop/issues/5687))
- **scoop-update:** Change error message to a better instruction ([#5677](https://github.com/ScoopInstaller/Scoop/issues/5677))
- **scoop-virustotal:** Fix `scoop-virustotal` when `--all` has been passed without app ([#5593](https://github.com/ScoopInstaller/Scoop/issues/5593))
- **scoop-virustotal:** Fix the issue that escape character not available in PowerShell 5.1 ([#5870](https://github.com/ScoopInstaller/Scoop/issues/5870))
- **autoupdate:** Fix file hash extraction ([#5295](https://github.com/ScoopInstaller/Scoop/issues/5295))
- **autoupdate:** Fix bug that 'WebClient' doesn't auto-extract 'gzip' ([#5901](https://github.com/ScoopInstaller/Scoop/issues/5901))
- **buckets:** Avoid error messages for unexpected dir ([#5549](https://github.com/ScoopInstaller/Scoop/issues/5549))
- **config:** Warn users about misconfigured GitHub token ([#5777](https://github.com/ScoopInstaller/Scoop/issues/5777))
- **core:** Fix scripts' calling parameters ([#5365](https://github.com/ScoopInstaller/Scoop/issues/5365))
- **core:** Fix `is_in_dir` under Unix ([#5391](https://github.com/ScoopInstaller/Scoop/issues/5391))
- **core:** Rewrite config file when needed ([#5439](https://github.com/ScoopInstaller/Scoop/issues/5439))
- **core:** Prevents leaking HTTP(S)_PROXY env vars to current sessions after Invoke-Git in parallel execution ([#5436](https://github.com/ScoopInstaller/Scoop/issues/5436))
- **core:** Handle scoop aliases and broken(edited,copied) shim ([#5551](https://github.com/ScoopInstaller/Scoop/issues/5551))
- **core:** Avoid error messages when deleting non-existent environment variable ([#5547](https://github.com/ScoopInstaller/Scoop/issues/5547))
- **core:** Use relative path as fallback of `$scoopdir` ([#5544](https://github.com/ScoopInstaller/Scoop/issues/5544))
- **core:** Fix detection of Git ([#5545](https://github.com/ScoopInstaller/Scoop/issues/5545))
- **core:** Do not call `scoop` externally from inside the code ([#5695](https://github.com/ScoopInstaller/Scoop/issues/5695))
- **core:** Fix arguments parsing method of `Invoke-ExternalCommand()` ([#5839](https://github.com/ScoopInstaller/Scoop/issues/5839))
- **decompress:** Exclude '*.nsis' that may cause error ([#5294](https://github.com/ScoopInstaller/Scoop/issues/5294))
- **decompress:** Remove unused parent dir w/ 'extract_dir' ([#5682](https://github.com/ScoopInstaller/Scoop/issues/5682))
- **decompress:** Use `wix.exe` in WiX Toolset v4+ as primary extractor of `Expand-DarkArchive()` ([#5871](https://github.com/ScoopInstaller/Scoop/issues/5871))
- **env:** Avoid automatic expansion of `%%` in env ([#5395](https://github.com/ScoopInstaller/Scoop/issues/5395), [#5452](https://github.com/ScoopInstaller/Scoop/issues/5452), [#5631](https://github.com/ScoopInstaller/Scoop/issues/5631))
- **getopt:** Stop split arguments in `getopt()` and ensure array by explicit arguments type ([#5326](https://github.com/ScoopInstaller/Scoop/issues/5326))
- **install:** Fix download from private GitHub repositories ([#5361](https://github.com/ScoopInstaller/Scoop/issues/5361))
- **install:** Avoid error when unlinking non-existent junction/hardlink ([#5552](https://github.com/ScoopInstaller/Scoop/issues/5552))
- **manifest:** Correct source of manifest ([#5575](https://github.com/ScoopInstaller/Scoop/issues/5575))
- **shim:** Remove console window for GUI applications ([#5559](https://github.com/ScoopInstaller/Scoop/issues/5559))
- **shim:** Use bash executable directly ([#5433](https://github.com/ScoopInstaller/Scoop/issues/5433))
- **shim:** Check literal path in `Get-ShimPath` ([#5680](https://github.com/ScoopInstaller/Scoop/issues/5680))
- **shim:** Avoid unexpected output of `list` subcommand ([#5681](https://github.com/ScoopInstaller/Scoop/issues/5681))
- **shim:** Allow GUI applications to attach to the shell's console when launched using the GUI shim ([#5721](https://github.com/ScoopInstaller/Scoop/issues/5721))
- **shim:** Run JAR file from app's root directory ([#5872](https://github.com/ScoopInstaller/Scoop/issues/5872))
- **shortcuts:** Output correctly formatted path ([#5333](https://github.com/ScoopInstaller/Scoop/issues/5333))
- **update/uninstall:** Remove items from PATH correctly ([#5833](https://github.com/ScoopInstaller/Scoop/issues/5833))

### Performance Improvements

- **scoop-search:** Improve performance for local search ([#5644](https://github.com/ScoopInstaller/Scoop/issues/5644))
- **scoop-update:** Check for running process before wasting time on download ([#5799](https://github.com/ScoopInstaller/Scoop/issues/5799))
- **decompress:** Disable progress bar to improve `Expand-Archive` performance ([#5410](https://github.com/ScoopInstaller/Scoop/issues/5410))
- **shim:** Update kiennq-shim to v3.1.1 ([#5841](https://github.com/ScoopInstaller/Scoop/issues/5841), [#5847](https://github.com/ScoopInstaller/Scoop/issues/5847))

### Code Refactoring

- **scoop-download:** Output more detailed manifest information ([#5277](https://github.com/ScoopInstaller/Scoop/issues/5277))
- **core:** Cleanup some old codes, e.g., msi section and config migration ([#5715](https://github.com/ScoopInstaller/Scoop/issues/5715), [#5824](https://github.com/ScoopInstaller/Scoop/issues/5824))
- **core:** Rewrite and separate path-related functions to `system.ps1` ([#5836](https://github.com/ScoopInstaller/Scoop/issues/5836), [#5858](https://github.com/ScoopInstaller/Scoop/issues/5858), [#5864](https://github.com/ScoopInstaller/Scoop/issues/5864))
- **core:** Get rid of 'fullpath' ([#3533](https://github.com/ScoopInstaller/Scoop/issues/3533))
- **git:** Use Invoke-Git() with direct path to git.exe to prevent spawning shim subprocesses ([#5122](https://github.com/ScoopInstaller/Scoop/issues/5122), [#5375](https://github.com/ScoopInstaller/Scoop/issues/5375))
- **helper:** Remove 7zip's fallback '7zip-zstd' ([#5548](https://github.com/ScoopInstaller/Scoop/issues/5548))
- **shim:** Remove CS shim codebase ([#5903](https://github.com/ScoopInstaller/Scoop/issues/5903))

### Builds

- **checkver:** Read the private_host config variable ([#5381](https://github.com/ScoopInstaller/Scoop/issues/5381))
- **supporting:** Update Json to 13.0.3, Json.Schema to 3.0.15 ([#5835](https://github.com/ScoopInstaller/Scoop/issues/5835))

### Continuous Integration

- **dependabot:** Add dependabot.yml for GitHub Actions ([#5377](https://github.com/ScoopInstaller/Scoop/issues/5377))
- **module:** Update 'psmodulecache' version to 'main' ([#5828](https://github.com/ScoopInstaller/Scoop/issues/5828))

### Tests

- **bucket:** Skip manifest validation if no manifest changes ([#5270](https://github.com/ScoopInstaller/Scoop/issues/5270))

### Documentation

- **scoop-info:** Fix help message([#5445](https://github.com/ScoopInstaller/Scoop/issues/5445))
- **readme:** Improve documentation language ([#5638](https://github.com/ScoopInstaller/Scoop/issues/5638))

## [v0.3.1](https://github.com/ScoopInstaller/Scoop/compare/v0.3.0...v0.3.1) - 2022-11-15

### Features

- **config:** Allow Scoop to check if apps versioned as 'nightly' are outdated ([#5166](https://github.com/ScoopInstaller/Scoop/issues/5166))
- **checkup:** Add Windows Developer Mode check ([#5233](https://github.com/ScoopInstaller/Scoop/issues/5233))
- **bucket:** Add 'sysinternals' bucket to known ([#5237](https://github.com/ScoopInstaller/Scoop/issues/5237))

### Bug Fixes

- **decompress:** Use PS's default 'Expand-Archive()' ([#5185](https://github.com/ScoopInstaller/Scoop/issues/5185))
- **hash:** Fix SourceForge's hash extraction ([#5189](https://github.com/ScoopInstaller/Scoop/issues/5189))
- **decompress:** Trim ending '/' ([#5195](https://github.com/ScoopInstaller/Scoop/issues/5195))
- **shim:** Exit if shim creating failed 'cause no git ([#5225](https://github.com/ScoopInstaller/Scoop/issues/5225))
- **scoop-import:** Add correct architecture argument ([#5210](https://github.com/ScoopInstaller/Scoop/issues/5210))
- **scoop-config:** Output `[DateTime]` as `[String]` ([#5232](https://github.com/ScoopInstaller/Scoop/issues/5232))
- **shim:** fixed shim add bug related to Resolve-Path ([#5492](https://github.com/ScoopInstaller/Scoop/issues/5492))

### Code Refactoring

- **hash:** Use `Get-FileHash()` directly ([#5177](https://github.com/ScoopInstaller/Scoop/issues/5177))
- **installer:** Drop the old installer ([#5186](https://github.com/ScoopInstaller/Scoop/issues/5186))
- **unix:** Remove `unix.ps1` ([#5235](https://github.com/ScoopInstaller/Scoop/issues/5235))

### Builds

- **auto-pr:** Add `CommitMessageFormat` option ([#5171](https://github.com/ScoopInstaller/Scoop/issues/5171))
- **checkver:** Support XML default namespace ([#5191](https://github.com/ScoopInstaller/Scoop/issues/5191))
- **pssa:** Remove unused 'ExcludeRules' ([#5201](https://github.com/ScoopInstaller/Scoop/issues/5201))
- **schema:** Add 'installer' and 'shortcuts' to 'autoupdate' ([#5220](https://github.com/ScoopInstaller/Scoop/issues/5220))
- **checkhashes:** Use correct version number if `UseCache` ([#5240](https://github.com/ScoopInstaller/Scoop/issues/5240))

### Continuous Integration

- **module:** Update modules version ([#5209](https://github.com/ScoopInstaller/Scoop/issues/5209))

### Tests

- **unix:** Fix tests in Linux and macOS ([#5179](https://github.com/ScoopInstaller/Scoop/issues/5179))
- **pester:** Update to Pester 5 ([#5222](https://github.com/ScoopInstaller/Scoop/issues/5222))
- **bucket:** Use BuildHelpers' EnvVars ([#5226](https://github.com/ScoopInstaller/Scoop/issues/5226))

### Documentation

- **scoop-cat:** Fix help message([#5224](https://github.com/ScoopInstaller/Scoop/issues/5224))

## [v0.3.0](https://github.com/ScoopInstaller/Scoop/compare/v0.2.4...v0.3.0) - 2022-10-10

### Features

- **install:** Add support for ARM64 architecture ([#5154](https://github.com/ScoopInstaller/Scoop/issues/5154))
- **install:** Show the running process ([#5102](https://github.com/ScoopInstaller/Scoop/issues/5102))
- **getopt:** Support option terminator (`--`) ([#5121](https://github.com/ScoopInstaller/Scoop/issues/5121))
- **subdir:** Allow subdir in 'bucket' ([#5119](https://github.com/ScoopInstaller/Scoop/issues/5119))
- **scoop-config:** Allow 'hold_update_until' be set manually ([#5100](https://github.com/ScoopInstaller/Scoop/issues/5100))
- **scoop-(un)hold:** Support `scoop (un)hold scoop` ([#5089](https://github.com/ScoopInstaller/Scoop/issues/5089))
- **scoop-update:** Stash uncommitted changes before update ([#5091](https://github.com/ScoopInstaller/Scoop/issues/5091))

### Bug Fixes

- **config:** Change config option to snake_case in file and SCREAMING_CASE in code ([#5116](https://github.com/ScoopInstaller/Scoop/issues/5116))
- **jsonpath:** Prevent converting date string to DateTime in JSONPath ([#5130](https://github.com/ScoopInstaller/Scoop/issues/5130))
- **psmodule:** Remove folder recursively when unlinking previous module path ([#5127](https://github.com/ScoopInstaller/Scoop/issues/5127))
- **scoop-update:** Add `uninstall_psmodule` to update process ([#5136](https://github.com/ScoopInstaller/Scoop/issues/5136))

### Code Refactoring

- **download:** Rename `dl()` to `Invoke-Download()` ([#5143](https://github.com/ScoopInstaller/Scoop/issues/5143))
- **path:** Use 'Convert-Path()' instead of 'Resolve-Path()' ([#5109](https://github.com/ScoopInstaller/Scoop/issues/5109))
- **scoop-shim:** Use `getopt` to parse arguments ([#5125](https://github.com/ScoopInstaller/Scoop/issues/5125))

### Builds

- **checkver:** Implement SourceForge checkver functionality ([#5113](https://github.com/ScoopInstaller/Scoop/issues/5113), [#5163](https://github.com/ScoopInstaller/Scoop/issues/5163))
- **checkurls:** Allow checking URLs from private_hosts ([#5152](https://github.com/ScoopInstaller/Scoop/issues/5152))
- **schema:** Set manifest schema to be stricter ([#5093](https://github.com/ScoopInstaller/Scoop/issues/5093))
- **vscode:** Tweak VSCode setting ([#5149](https://github.com/ScoopInstaller/Scoop/issues/5149))

## [v0.2.4](https://github.com/ScoopInstaller/Scoop/compare/v0.2.3...v0.2.4) - 2022-08-08

### Features

- **core:** Create no window by default in `Invoke-ExternalCommand` ([#5066](https://github.com/ScoopInstaller/Scoop/issues/5066))
- **core:** Improve argument concatenation in `Invoke-ExternalCommand` ([#5065](https://github.com/ScoopInstaller/Scoop/issues/5065))
- **install:** Show bucket name while installing an app ([#5075](https://github.com/ScoopInstaller/Scoop/issues/5075))
- **scoop-status:** Add flag to disable remote checking ([#5073](https://github.com/ScoopInstaller/Scoop/issues/5073))
- **scoop-update:** Add support for `pre_uninstall` and `post_uninstall` ([#5085](https://github.com/ScoopInstaller/Scoop/issues/5085))

### Bug Fixes

- **core:** Avoid deadlock in `Invoke-ExternalCommand` ([#5064](https://github.com/ScoopInstaller/Scoop/issues/5064))
- **core:** Use 'System.Nullable<bool>' for param 'global' ([#5088](https://github.com/ScoopInstaller/Scoop/issues/5088))
- **install:** Move from cache when `--no-cache` is specified ([#5039](https://github.com/ScoopInstaller/Scoop/issues/5039))
- **scoop-status:** Correct formatting of `Info` output ([#5047](https://github.com/ScoopInstaller/Scoop/issues/5047))

### Builds

- **checkver:** Load page content before running 'script' ([#5080](https://github.com/ScoopInstaller/Scoop/issues/5080))
- **json:** Update Newtonsoft.Json.Schema to 3.0.15-beta2 ([#5053](https://github.com/ScoopInstaller/Scoop/issues/5053))

## [v0.2.3](https://github.com/ScoopInstaller/Scoop/compare/v0.2.2...v0.2.3) - 2022-07-07

### Features

- **chore:** Add missing -a/--all param to all commands ([#5004](https://github.com/ScoopInstaller/Scoop/issues/5004))
- **scoop-status:** Check bucket status, improve output ([#5011](https://github.com/ScoopInstaller/Scoop/issues/5011))
- **scoop-info:** Show app installed/download size ([#4886](https://github.com/ScoopInstaller/Scoop/issues/4886))
- **scoop-import:** Import a Scoop installation from JSON ([#5014](https://github.com/ScoopInstaller/Scoop/issues/5014), [#5034](https://github.com/ScoopInstaller/Scoop/issues/5034))

### Bug Fixes

- **chore:** Update help documentation ([#5002](https://github.com/ScoopInstaller/Scoop/issues/5002), [#5029](https://github.com/ScoopInstaller/Scoop/issues/5029))
- **decompress:** Handle split RAR archives ([#4994](https://github.com/ScoopInstaller/Scoop/issues/4994))
- **shortcuts:** Fix network drive shortcut creation ([#4410](https://github.com/ScoopInstaller/Scoop/issues/4410), [#5006](https://github.com/ScoopInstaller/Scoop/issues/5006))

### Code Refactoring

- **scoop-search:** Output PSObject, use API token ([#4997](https://github.com/ScoopInstaller/Scoop/issues/4997))

### Builds

- **checkver,auto-pr:** Allow passing file path ([#5019](https://github.com/ScoopInstaller/Scoop/issues/5019))
- **checkver:** Exit routine earlier if error ([#5025](https://github.com/ScoopInstaller/Scoop/issues/5025))
- **json:** Update Newton.Json to 13.0.1 ([#5026](https://github.com/ScoopInstaller/Scoop/issues/5026))

### Tests

- **typo:** Fix typo ('formated' -> 'formatted') ([#4217](https://github.com/ScoopInstaller/Scoop/issues/4217))

## [v0.2.2](https://github.com/ScoopInstaller/Scoop/compare/v0.2.1...v0.2.2) - 2022-06-21

### Features

- **core:** Add `Get-Encoding` function to fix missing webclient encoding ([#4956](https://github.com/ScoopInstaller/Scoop/issues/4956))
- **scoop-(un)hold:** Add `-g`/`--global` flag ([#4991](https://github.com/ScoopInstaller/Scoop/issues/4991))
- **scoop-update:** Support `scoop update scoop` ([#4992](https://github.com/ScoopInstaller/Scoop/issues/4992))
- **scoop-virustotal:** Migrate to VirusTotal API v3 ([#4983](https://github.com/ScoopInstaller/Scoop/issues/4983))

### Bug Fixes

- **manifest:** Fix bugs in 'Get-Manifest()' ([#4986](https://github.com/ScoopInstaller/Scoop/issues/4986))

## [v0.2.1](https://github.com/ScoopInstaller/Scoop/compare/v0.2.0...v0.2.1) - 2022-06-10

### Features

- **core:** Add pre_uninstall and post_uninstall hooks ([#4957](https://github.com/ScoopInstaller/Scoop/issues/4957), [#4962](https://github.com/ScoopInstaller/Scoop/issues/4962))

### Bug Fixes

- **bucket:** Make sure `list_buckets` return array ([#4979](https://github.com/ScoopInstaller/Scoop/issues/4979))
- **chore:** Deprecate tls1 and tls1.1 ([#4950](https://github.com/ScoopInstaller/Scoop/issues/4950))
- **chore:** Update Nonportable bucket URL ([#4955](https://github.com/ScoopInstaller/Scoop/issues/4955))
- **core:** Using `Invoke-Command` instead of `Invoke-Expression` ([#4941](https://github.com/ScoopInstaller/Scoop/issues/4941))
- **core:** Load config file before initialization ([#4932](https://github.com/ScoopInstaller/Scoop/issues/4932))
- **core:** Allow to use '_' and '.' in bucket name ([#4952](https://github.com/ScoopInstaller/Scoop/issues/4952))
- **depends:** Avoid digits in archive file extension (except for .7z and .001) ([#4915](https://github.com/ScoopInstaller/Scoop/issues/4915))
- **bucket:** Don't check remote URL of non-git buckets ([#4923](https://github.com/ScoopInstaller/Scoop/issues/4923))
- **bucket:** Don't write message OK before bucket is cloned ([#4925](https://github.com/ScoopInstaller/Scoop/issues/4925))
- **shim:** Add 'Get-CommandPath()' to find git ([#4913](https://github.com/ScoopInstaller/Scoop/issues/4913))
- **shim:** Remove character replacement in .cmd -> .ps1 shims ([#4914](https://github.com/ScoopInstaller/Scoop/issues/4914))
- **scoop:** Pass CLI arguments as string objects ([#4931](https://github.com/ScoopInstaller/Scoop/issues/4931))
- **scoop-info:** Fix error message when manifest is not found ([#4935](https://github.com/ScoopInstaller/Scoop/issues/4935))
- **scoop-search:** Require files in 'bucket' dir for remote known buckets ([#4944](https://github.com/ScoopInstaller/Scoop/issues/4944))
- **update:** Prevent uninstall when update ([#4949](https://github.com/ScoopInstaller/Scoop/issues/4949))
- **scoop-download:** Use correct Args when calling `Get-Manifest` ([#4970](https://github.com/ScoopInstaller/Scoop/issues/4970))

### Code Refactoring

- **manifest:** Rename 'Find-Manifest()' to 'Get-Manifest() ([#4966](https://github.com/ScoopInstaller/Scoop/issues/4966), [#4981](https://github.com/ScoopInstaller/Scoop/issues/4981))

### Documentation

- **readme:** Update license badge ([#4929](https://github.com/ScoopInstaller/Scoop/issues/4929))

## [v0.2.0](https://github.com/ScoopInstaller/Scoop/compare/v0.1.0...v0.2.0) - 2022-05-10

### Features

- **relicense:** Relicense to dual-license (Unlicense or MIT) ([#4903](https://github.com/ScoopInstaller/Scoop/issues/4903), [#4870](https://github.com/ScoopInstaller/Scoop/issues/4870))
- **install:** Allow downloading from private repositories ([#4254](https://github.com/ScoopInstaller/Scoop/issues/4254))
- **scoop-cleanup:** Add `-a/--all` switch to cleanup all apps ([#4906](https://github.com/ScoopInstaller/Scoop/issues/4906))

### Bug Fixes

- **bucket:** Return empty list correctly in `Get-LocalBucket` ([#4885](https://github.com/ScoopInstaller/Scoop/issues/4885))
- **install:** Fix issue with installation inside containers ([#4837](https://github.com/ScoopInstaller/Scoop/issues/4837))
- **installed:** If no `$global`, check both local and global installed ([#4798](https://github.com/ScoopInstaller/Scoop/issues/4798))
- **shim:** Manipulating shims with UTF8 encoding ([#4791](https://github.com/ScoopInstaller/Scoop/issues/4791), [#4813](https://github.com/ScoopInstaller/Scoop/issues/4813))
- **shim:** Correctly quote $@ in sh->ps1 shims ([#4809](https://github.com/ScoopInstaller/Scoop/issues/4809))
- **update:** Skip logs starting with `(chore)` ([#4800](https://github.com/ScoopInstaller/Scoop/issues/4800))
- **scoop-download:** Add failure check ([#4822](https://github.com/ScoopInstaller/Scoop/issues/4822))
- **scoop-list:** Fix date in 'Updated' column showing the months in the place of minutes ([#4880](https://github.com/ScoopInstaller/Scoop/issues/4880))
- **scoop-prefix:** Fix typo that breaks global installed apps ([#4795](https://github.com/ScoopInstaller/Scoop/issues/4795))

### Performance Improvements

- **scoop:** Load libs only once ([#4839](https://github.com/ScoopInstaller/Scoop/issues/4839), [#4884](https://github.com/ScoopInstaller/Scoop/issues/4884))

### Code Refactoring

- **bucket:** Move 'Find-Manifest' and 'list_buckets' to 'buckets' ([#4814](https://github.com/ScoopInstaller/Scoop/issues/4814))
- **relpath:** Use `$PSScriptRoot` instead of `relpath` ([#4793](https://github.com/ScoopInstaller/Scoop/issues/4793))
- **reset_aliases:** Move core function of `reset_aliases` to `scoop` ([#4794](https://github.com/ScoopInstaller/Scoop/issues/4794))
- **config:** Rename checkver_token to gh_token and SCOOP_CHECKVER_TOKEN to SCOOP_GH_TOKEN ([#4832](https://github.com/ScoopInstaller/Scoop/issues/4832), [#4842](https://github.com/ScoopInstaller/Scoop/issues/4842))

### Builds

- **checkver:** Add option to throw error as exception ([#4867](https://github.com/ScoopInstaller/Scoop/issues/4867))
- **schema:** Remove 'description' from required fields ([#4853](https://github.com/ScoopInstaller/Scoop/issues/4853), [#4874](https://github.com/ScoopInstaller/Scoop/issues/4874))

### Documentation

- **changelog:** Rearrange CHANGELOG ([#4897](https://github.com/ScoopInstaller/Scoop/issues/4897))
- **readme:** Update installation instruction ([#4825](https://github.com/ScoopInstaller/Scoop/issues/4825))
- **readme:** Fix badges for Gitter and CI Tests ([#4830](https://github.com/ScoopInstaller/Scoop/issues/4830))
- **scoop-shim:** Fix typo ([#4836](https://github.com/ScoopInstaller/Scoop/issues/4836))

## [v0.1.0](https://github.com/ScoopInstaller/Scoop/compare/2021-12-26...v0.1.0) - 2022-03-01

### Features

- **scoop-bucket:** List more detailed information for buckets ([#4704](https://github.com/ScoopInstaller/Scoop/issues/4704), [#4756](https://github.com/ScoopInstaller/Scoop/issues/4756), [#4759](https://github.com/ScoopInstaller/Scoop/issues/4759))
- **scoop-cache:** Handle multiple apps and show detailed information ([#4738](https://github.com/ScoopInstaller/Scoop/issues/4738))
- **scoop-cat:** Use `bat` to pretty-print JSON ([#4742](https://github.com/ScoopInstaller/Scoop/issues/4742))
- **scoop-config:** Allow Scoop to ignore running processes during reset/uninstall/update ([#4713](https://github.com/ScoopInstaller/Scoop/issues/4713), [#4731](https://github.com/ScoopInstaller/Scoop/issues/4731))
- **scoop-config:** Show all settings ([#4765](https://github.com/ScoopInstaller/Scoop/issues/4765))
- **scoop-download:** Add `scoop download` command ([#4621](https://github.com/ScoopInstaller/Scoop/issues/4621))
- **scoop-(install|virustotal):** Allow skipping update check ([#4634](https://github.com/ScoopInstaller/Scoop/issues/4634))
- **scoop-list:** Allow list manipulation ([#4718](https://github.com/ScoopInstaller/Scoop/issues/4718))
- **scoop-list:** Show last-updated time ([#4723](https://github.com/ScoopInstaller/Scoop/issues/4723))
- **scoop-info:** Revamp details and show more information ([#4747](https://github.com/ScoopInstaller/Scoop/issues/4747))
- **scoop-shim:** Add `scoop shim` to manipulate shims ([#4727](https://github.com/ScoopInstaller/Scoop/issues/4727), [#4736](https://github.com/ScoopInstaller/Scoop/issues/4736))

### Bug Fixes

- **autoupdate:** Allow checksum file that contains whitespaces ([#4619](https://github.com/ScoopInstaller/Scoop/issues/4619))
- **autoupdate:** Rename $response to $res ([#4706](https://github.com/ScoopInstaller/Scoop/issues/4706))
- **config:** Ensure manipulating config with UTF8 encoding ([#4644](https://github.com/ScoopInstaller/Scoop/issues/4644))
- **config:** Allow scoop config use Unicode characters ([#4631](https://github.com/ScoopInstaller/Scoop/issues/4631))
- **config:** Fix `set_config` bugs ([#3681](https://github.com/ScoopInstaller/Scoop/issues/3681))
- **current:** Remove 'current' while it's not a junction ([#4687](https://github.com/ScoopInstaller/Scoop/issues/4687))
- **depends:** Prevent error on no URL ([#4595](https://github.com/ScoopInstaller/Scoop/issues/4595))
- **depends:** Check if extractor is available ([#4042](https://github.com/ScoopInstaller/Scoop/issues/4042))
- **decompress:** Fix nested Zstd archive extraction ([#4608](https://github.com/ScoopInstaller/Scoop/issues/4608), [#4639](https://github.com/ScoopInstaller/Scoop/issues/4639))
- **installed:** Fix 'core/installed' that mark failed app as 'installed' ([#4650](https://github.com/ScoopInstaller/Scoop/issues/4650), [#4676](https://github.com/ScoopInstaller/Scoop/issues/4676), [#4689](https://github.com/ScoopInstaller/Scoop/issues/4689), [#4785](https://github.com/ScoopInstaller/Scoop/issues/4785))
- **no-junctions:** Fix error when `NO_JUNCTIONS` is been set ([#4722](https://github.com/ScoopInstaller/Scoop/issues/4722), [#4726](https://github.com/ScoopInstaller/Scoop/issues/4726))
- **shim:** Fix PS1 shim error when in different drive in PS7 ([#4614](https://github.com/ScoopInstaller/Scoop/issues/4614))
- **shim:** Fix `sh` shim error in WSL ([#4637](https://github.com/ScoopInstaller/Scoop/issues/4637))
- **shim:** Use `-file` instead of `-command` in ps1 script shims ([#4721](https://github.com/ScoopInstaller/Scoop/issues/4721))
- **shim:** Fix exe shim when app path has white spaces ([#4734](https://github.com/ScoopInstaller/Scoop/issues/4734), [#4780](https://github.com/ScoopInstaller/Scoop/issues/4780))
- **versions:** Fix wrong version number when only one version dir ([#4679](https://github.com/ScoopInstaller/Scoop/issues/4679))
- **versions:** Get current version from failed installation if possible ([#4720](https://github.com/ScoopInstaller/Scoop/issues/4720), [#4725](https://github.com/ScoopInstaller/Scoop/issues/4725))
- **scoop-alias:** Fix alias initialization ([#4737](https://github.com/ScoopInstaller/Scoop/issues/4737))
- **scoop-checkup:** Skip 'check_windows_defender' when have not admin privileges ([#4699](https://github.com/ScoopInstaller/Scoop/issues/4699))
- **scoop-cleanup:** Remove apps other than current version ([#4665](https://github.com/ScoopInstaller/Scoop/issues/4665))
- **scoop-search:** Remove redundant 'bucket/' in search result ([#4773](https://github.com/ScoopInstaller/Scoop/issues/4773))
- **scoop-update:** Skip updating non git buckets ([#4670](https://github.com/ScoopInstaller/Scoop/issues/4670), [#4672](https://github.com/ScoopInstaller/Scoop/issues/4672))

### Performance Improvements

- **uninstall:** Avoid checking all files for unlinking persisted data ([#4681](https://github.com/ScoopInstaller/Scoop/issues/4681), [#4763](https://github.com/ScoopInstaller/Scoop/issues/4763))

### Code Refactoring

- **depends:** Rewrite 'depends.ps1' ([#4638](https://github.com/ScoopInstaller/Scoop/issues/4638), [#4673](https://github.com/ScoopInstaller/Scoop/issues/4673))
- **mklink:** Use 'New-Item' instead of 'mklink' ([#4690](https://github.com/ScoopInstaller/Scoop/issues/4690))
- **rmdir:** Use 'Remove-Item' instead of 'rmdir' ([#4691](https://github.com/ScoopInstaller/Scoop/issues/4691))
- **COMSPEC:** Deprecate use of subshell cmd.exe ([#4692](https://github.com/ScoopInstaller/Scoop/issues/4692))
- **git:** Use 'git -C' to specify the work directory instead of 'Push-Location'/'Pop-Location' ([#4697](https://github.com/ScoopInstaller/Scoop/issues/4697))
- **scoop-info:** Use List View for output ([#4741](https://github.com/ScoopInstaller/Scoop/issues/4741))
- **scoop-config:** Use underscores everywhere ([#4745](https://github.com/ScoopInstaller/Scoop/issues/4745))

### Builds

- **checkver:** Fix output with '-Version' ([#3774](https://github.com/ScoopInstaller/Scoop/issues/3774))
- **schema:** Add '$schema' property ([#4623](https://github.com/ScoopInstaller/Scoop/issues/4623))
- **schema:** Add explicit escape to opening bracket matcher in jp/jsonpath regex ([#3719](https://github.com/ScoopInstaller/Scoop/issues/3719))
- **schema:** Fix typo ('note' -> 'notes') ([#4678](https://github.com/ScoopInstaller/Scoop/issues/4678))
- **tests:** Support both AppVeyor and GitHub Actions ([#4655](https://github.com/ScoopInstaller/Scoop/issues/4655))
- **tests:** Run GitHub Actions CI on each commit ([#4664](https://github.com/ScoopInstaller/Scoop/issues/4664))
- **tests:** Use cache in GitHub Actions ([#4671](https://github.com/ScoopInstaller/Scoop/issues/4671))
- **tests:** Disable CI test on 'push' ([#4677](https://github.com/ScoopInstaller/Scoop/issues/4677))
- **vscode-settings:** Remove 'formatOnSave' trigger ([#4635](https://github.com/ScoopInstaller/Scoop/issues/4635))

### Styles

- **test:** Format scripts by VSCode's PowerShell extension ([#4609](https://github.com/ScoopInstaller/Scoop/issues/4609))
- **style:** Use correct casing for `$PSScriptRoot` ([#4775](https://github.com/ScoopInstaller/Scoop/issues/4775))

### Tests

- **test-bin:** Only write output file in CI and fix trailing whitespaces ([#4613](https://github.com/ScoopInstaller/Scoop/issues/4613))
- **manifest:** Fix manifests validation ([#4620](https://github.com/ScoopInstaller/Scoop/issues/4620))
- **zstd:** Fix 'zstd' extraction error in test ([#4651](https://github.com/ScoopInstaller/Scoop/issues/4651))

### Documentation

- **changelog:** Add 'CHANGLOG.md' ([#4600](https://github.com/ScoopInstaller/Scoop/issues/4600))
- **changelog:** Rearrange CHANGELOG ([#4729](https://github.com/ScoopInstaller/Scoop/issues/4729))
- **changelog:** Link CHANGELOG headers to 'releases/tag' ([#4730](https://github.com/ScoopInstaller/Scoop/issues/4730))

## [2021-12-26](https://github.com/ScoopInstaller/Scoop/compare/2021-11-22...2021-12-26)

### Features

- **core:** Redirect 'StandardError' in `Invoke-ExternalCommand()` ([#4570](https://github.com/ScoopInstaller/Scoop/issues/4570), [#4582](https://github.com/ScoopInstaller/Scoop/issues/4582))
- **install:** Add portableapps.com to strip_filename skips ([#3244](https://github.com/ScoopInstaller/Scoop/issues/3244))
- **install:** Show manifest on installation ([#4155](https://github.com/ScoopInstaller/Scoop/issues/4155), [fb496c48](https://github.com/ScoopInstaller/Scoop/commit/fb496c482bec4063e01b328f943224ab703dbbd8), [#4581](https://github.com/ScoopInstaller/Scoop/issues/4581))
- **template:** Add issue/PR templates ([#4572](https://github.com/ScoopInstaller/Scoop/issues/4572))
- **scoop-cat:** Add `scoop cat` command ([#4532](https://github.com/ScoopInstaller/Scoop/issues/4532))
- **scoop-config:** Document all configuration options ([#4579](https://github.com/ScoopInstaller/Scoop/issues/4579))

### Bug Fixes

- **bucket:** Remove JetBrains bucket ([dec25980](https://github.com/ScoopInstaller/Scoop/commit/dec25980525a81c176b3fd5f238e964db00f3be3))
- **bucket:** Remove nightlies bucket ([48b035d7](https://github.com/ScoopInstaller/Scoop/commit/48b035d7f99baa2e81d87ead4ff03a9594e49c3d))
- **core:** Escape '.' in 'parse_app()'. ([#4578](https://github.com/ScoopInstaller/Scoop/issues/4578))
- **core:** Use '-Encoding ASCII' in 'Out-File' ([#4571](https://github.com/ScoopInstaller/Scoop/issues/4571))
- **depends:** Specify function scope ([4d5fee36](https://github.com/ScoopInstaller/Scoop/commit/4d5fee36e1ed13fc850fd22a5414186aec030c6e))
- **install:** Use `Select-CurrentVersion` ([#4535](https://github.com/ScoopInstaller/Scoop/issues/4535))
- **install:** 'env_add_path' doesn't append '.' ([#4550](https://github.com/ScoopInstaller/Scoop/issues/4550))
- **repo:** Update repo links ([cbe29edd](https://github.com/ScoopInstaller/Scoop/commit/cbe29eddb3475e34740300eb1c2c52715446e3be))
- **scoop-update:** Update apps with '--all' ([ac71fccb](https://github.com/ScoopInstaller/Scoop/commit/ac71fccbecb3d4158f249db9c1b9bb043cb8e966))
- **scoop-update:** Fix scoop update -a requiring arguments ([#4531](https://github.com/ScoopInstaller/Scoop/issues/4531))

### Code Refactoring

- **shim:** Rework shimming logic ([#4543](https://github.com/ScoopInstaller/Scoop/issues/4543), [#4555](https://github.com/ScoopInstaller/Scoop/issues/4555), [3c90d1a0](https://github.com/ScoopInstaller/Scoop/commit/3c90d1a0701b0b64730dbf9ebc8d31f9b9c238f1), [2ec00d57](https://github.com/ScoopInstaller/Scoop/commit/2ec00d576c7e594dc5c0f1eac4536c5310ce6f17))

### Builds

- **auto-pr:** Remove hardcoded 'master' branch ([#4567](https://github.com/ScoopInstaller/Scoop/issues/4567))
- **checkver:** Improve JSONPath extraction support ([#4522](https://github.com/ScoopInstaller/Scoop/issues/4522))
- **checkver:** Use GitHub token from environment ([#4557](https://github.com/ScoopInstaller/Scoop/issues/4557))
- **schema:** Enable autoupdate for 'license' ([#4528](https://github.com/ScoopInstaller/Scoop/issues/4528), [#4596](https://github.com/ScoopInstaller/Scoop/issues/4596))

### Documentation

- **readme:** Add link to Contributing Guide ([5e11c94a](https://github.com/ScoopInstaller/Scoop/commit/5e11c94a544ff2adbdbec5072c32a94d3e5acb9c))
- **readme:** Fix links ([3bb7036e](https://github.com/ScoopInstaller/Scoop/commit/3bb7036ee111bfe58e82ba3d0fd39189b058776a))

### Reverts

- **shim:** Revert [#4229](https://github.com/ScoopInstaller/Scoop/issues/4229) ([#4553](https://github.com/ScoopInstaller/Scoop/issues/4553))

## [2021-11-22](https://github.com/ScoopInstaller/Scoop/compare/2020-11-26...2021-11-22)

### Features

- **bucket:** Move extras bucket to [@ScoopInstaller](https://github.com/ScoopInstaller) ([3e9a4d4e](https://github.com/ScoopInstaller/Scoop/commit/3e9a4d4ea0e7e4d6489099c46a763f58db07e633))
- **decompress:** Support Zstandard archive ([#4372](https://github.com/ScoopInstaller/Scoop/issues/4372), [e35ff313](https://github.com/ScoopInstaller/Scoop/commit/e35ff313a5d35cab1049024938c3423a5f6bf060), [47ebc6f1](https://github.com/ScoopInstaller/Scoop/commit/47ebc6f176b0db0afeb51b4ee237a20b2d8649e9))
- **install:** Handle arch-specific env_add_path ([#4013](https://github.com/ScoopInstaller/Scoop/issues/4013))
- **install:** s/lukesamson/ScoopInstaller in install.ps1 ([5226f26f](https://github.com/ScoopInstaller/Scoop/commit/5226f26f18157ed78f1529144404ec682374452e))
- **message:** Add config to disable aria2 warning message ([#4422](https://github.com/ScoopInstaller/Scoop/issues/4422))
- **shim:** Add another alternative shim written in rust ([#4229](https://github.com/ScoopInstaller/Scoop/issues/4229))
- **scoop-prefix:** Remove unused imports and functions ([#4494](https://github.com/ScoopInstaller/Scoop/issues/4494))
- **scoop-install:** Auto uninstall previous failed installation ([#3281](https://github.com/ScoopInstaller/Scoop/issues/3281))
- **scoop-update:** Add flags `--all` as an alternative to '*' to update all ([#3871](https://github.com/ScoopInstaller/Scoop/issues/3871))

### Bug Fixes

- **core:** Change url() scope to avoid conflict with global aliases ([#4342](https://github.com/ScoopInstaller/Scoop/issues/4342), [#4492](https://github.com/ScoopInstaller/Scoop/issues/4492))
- **install:** Fix `aria2`'s resume download feature ([#3292](https://github.com/ScoopInstaller/Scoop/issues/3292))
- **shim:** Fixed trailing whitespace issue ([#4307](https://github.com/ScoopInstaller/Scoop/issues/4307))
- **scoop-reset:** Skip when app instance is running ([#4359](https://github.com/ScoopInstaller/Scoop/issues/4359))

### Code Refactoring

- **versions:** Refactor 'versions.ps1' ([#3721](https://github.com/ScoopInstaller/Scoop/issues/3721), [e6630272](https://github.com/ScoopInstaller/Scoop/commit/e663027299d03ca768a252fa4bcbc51d124d4cae), [ae892138](https://github.com/ScoopInstaller/Scoop/commit/ae892138423bb9bbf54c8f0bed8331b93199f6b8))

### Builds

- **autoupdate:** Add multiple URL/hash/extract_dir... support ([#3518](https://github.com/ScoopInstaller/Scoop/issues/3518), [#4502](https://github.com/ScoopInstaller/Scoop/issues/4502))
- **schema:** Fix Schema to support `+` in version ([#4504](https://github.com/ScoopInstaller/Scoop/issues/4504))
- **supporting:** Update Json to 12.0.3, Json.Schema to 3.0.14 ([#3352](https://github.com/ScoopInstaller/Scoop/issues/3352))

### Documentation

- **readme:** Capitalize to prevent redirect ([#4483](https://github.com/ScoopInstaller/Scoop/issues/4483))
- **readme:** s/lukesampson/ScoopInstaller in readme ([4f5acd72](https://github.com/ScoopInstaller/Scoop/commit/4f5acd72109a98a148d1bfa269c23a2d43644d23))
- **readme:** Update extras bucket url in readme ([f1a46e10](https://github.com/ScoopInstaller/Scoop/commit/f1a46e109596c55c7e83c77fc1fc9daedbe71636))
- **readme:** Update Java bucket text ([#4514](https://github.com/ScoopInstaller/Scoop/issues/4514))
- **readme:** Update notes about the NirSoft bucket ([#4524](https://github.com/ScoopInstaller/Scoop/issues/4524))

## [2020-11-26](https://github.com/ScoopInstaller/Scoop/compare/2020-10-22...2020-11-26)

### Bug Fixes

- **shim:** Fix Makefile typo ([0948824e](https://github.com/ScoopInstaller/Scoop/commit/0948824ec7269c979882d09342d9a269193cd674)) ([227de6cf](https://github.com/ScoopInstaller/Scoop/commit/227de6cfb8433a86ac0f0a279e691327ae04554c))

## [2020-10-22](https://github.com/ScoopInstaller/Scoop/compare/2019-10-23...2020-10-22)

### Features

- **aria2:** Inline progress ([#3987](https://github.com/ScoopInstaller/Scoop/issues/3987))
- **autoupdate:** Add $urlNoExt and $basenameNoExt substitutions ([#3742](https://github.com/ScoopInstaller/Scoop/issues/3742))
- **config:** Add configuration option for default architecture ([#3778](https://github.com/ScoopInstaller/Scoop/issues/3778))
- **install:** Follow HTTP redirections when downloading a file ([#3902](https://github.com/ScoopInstaller/Scoop/issues/3902))
- **install:** Let pathes in 'env_add_path' be added ascendantly ([#3788](https://github.com/ScoopInstaller/Scoop/issues/3788), [#3976](https://github.com/ScoopInstaller/Scoop/issues/3976))
- **list:** Display main bucket name ([#3759](https://github.com/ScoopInstaller/Scoop/issues/3759))
- **shim:** Add alt-shim support ([#3998](https://github.com/ScoopInstaller/Scoop/issues/3998))
- **scoop-checkup:** Add check_envs_requirements ([#3860](https://github.com/ScoopInstaller/Scoop/issues/3860))

### Bug Fixes

- **bucket:** Update scoop-nonportable URL ([#3776](https://github.com/ScoopInstaller/Scoop/issues/3776))
- **download:** Fosshub download ([#4051](https://github.com/ScoopInstaller/Scoop/issues/4051))
- **download:** Progress bar on small files ([96de9c14](https://github.com/ScoopInstaller/Scoop/commit/96de9c14bb483f9278e4b0a9e22b1923ee752901))
- **hold:** Replace "locked" terminology with "held" for consistency ([#3917](https://github.com/ScoopInstaller/Scoop/issues/3917))
- **git:** Don't execute autostart programs when executing git commands ([#3993](https://github.com/ScoopInstaller/Scoop/issues/3993))
- **git:** Enforce pull without rebase ([#3765](https://github.com/ScoopInstaller/Scoop/issues/3765))
- **install:** Aria2 inline progress negative values ([#4053](https://github.com/ScoopInstaller/Scoop/issues/4053))
- **install:** Fix wrong output of 'install/failed' ([#3784](https://github.com/ScoopInstaller/Scoop/issues/3784), [#3867](https://github.com/ScoopInstaller/Scoop/issues/3867))
- **install:** Re-add "Don't send referer to portableapps.com" ([#3961](https://github.com/ScoopInstaller/Scoop/issues/3961))
- **scoop:** Remove temporary code from the scoop executable ([#3898](https://github.com/ScoopInstaller/Scoop/issues/3898))
- **update:** Update outdated PowerShell 5 warning ([#3986](https://github.com/ScoopInstaller/Scoop/issues/3986))
- **scoop-info:** Check bucket of installed app ([#3740](https://github.com/ScoopInstaller/Scoop/issues/3740))

### Builds

- **checkver:** Present script property ([#3900](https://github.com/ScoopInstaller/Scoop/issues/3900))

### Tests

- **init:** Force pester v4 ([#4040](https://github.com/ScoopInstaller/Scoop/issues/4040))

## [2019-10-23](https://github.com/ScoopInstaller/Scoop/compare/2019-10-18...2019-10-23)

### Features

- **update:** Support $persist_dir in uninstaller.script ([#3692](https://github.com/ScoopInstaller/Scoop/issues/3692))

### Bug Fixes

- **core:** Use [Environment]::Is64BitOperatingSystem instead of [intptr]::size ([#3690](https://github.com/ScoopInstaller/Scoop/issues/3690))
- **git:** Remove unnecessary git_proxy_cmd() calls for local commands ([8ee45a57](https://github.com/ScoopInstaller/Scoop/commit/8ee45a57dc01a525dcf8776bf9bb45263992c81f))
- **install:** Check execution policy ([#3619](https://github.com/ScoopInstaller/Scoop/issues/3619))
- **update:** Fix scoop update changelog output ([e997017f](https://github.com/ScoopInstaller/Scoop/commit/e997017f1a03e2eefef2157acdfefe2e4fced896))

## [2019-10-18](https://github.com/ScoopInstaller/Scoop/compare/2019-06-24...2019-10-18)

### Features

- **core:** Tweak Invoke-ExternalCommand parameters ([#3547](https://github.com/ScoopInstaller/Scoop/issues/3547))
- **install:** Use 7zip when available for faster zip file extraction ([#3460](https://github.com/ScoopInstaller/Scoop/issues/3460))
- **install:** Add arch support to `env_add_path` and `env_set` ([#3503](https://github.com/ScoopInstaller/Scoop/issues/3503))
- **install:** Allow $version to be used in uninstaller scripts ([#3592](https://github.com/ScoopInstaller/Scoop/issues/3592))
- **install:** Allow installing specific version if latest is installed ([11c42d78](https://github.com/ScoopInstaller/Scoop/commit/11c42d782f8adb29fbe0d94daa5f121cdda935ab))
- **update:** Allow updating apps from local manifest or URL ([#3685](https://github.com/ScoopInstaller/Scoop/issues/3685))

### Bug Fixes

- **autoupdate:** Decode basename when extract hash ([#3615](https://github.com/ScoopInstaller/Scoop/issues/3615))
- **autoupdate:** Remove any whitespace from hash ([#3579](https://github.com/ScoopInstaller/Scoop/issues/3579))
- **bucket:** Only lookup directories in buckets folder ([#3631](https://github.com/ScoopInstaller/Scoop/issues/3631))
- **comspec:** Escape variables when calling COMSPEC commands ([#3538](https://github.com/ScoopInstaller/Scoop/issues/3538))
- **decompress:** Fix bugs on extract_dir ([#3540](https://github.com/ScoopInstaller/Scoop/issues/3540))
- **editorconfig:** Add missing } to bat/cmd regex ([#3529](https://github.com/ScoopInstaller/Scoop/issues/3529))
- **help:** Rename help() to scoop_help() ([#3564](https://github.com/ScoopInstaller/Scoop/issues/3564))
- **install:** Use Join-Path instead of string gluing. ([#3566](https://github.com/ScoopInstaller/Scoop/issues/3566))
- **scoop-info:** Fix output for single binaries with alias ([#3651](https://github.com/ScoopInstaller/Scoop/issues/3651))
- **scoop-info:** Remove a whitespace ([#3652](https://github.com/ScoopInstaller/Scoop/issues/3652))

### Builds

- **auto-pr:** Fix git status detection ([7decfd4c](https://github.com/ScoopInstaller/Scoop/commit/7decfd4c107b8d8a59d7eedfe8a56e1801120c2f))
- **auto-pr:** Hard reset bucket after running ([79f8538b](https://github.com/ScoopInstaller/Scoop/commit/79f8538b57b9021db71a279879b9032fefd1ae52))
- **checkurls:** Trim renaming suffix in url ([#3677](https://github.com/ScoopInstaller/Scoop/issues/3677))

### Continuous Integration

- **appveyor:** use VS2019 image to fix PS6 issues ([#3646](https://github.com/ScoopInstaller/Scoop/issues/3646))
- **tests:** Do not force maintainers to have SCOOP_HELPERS ([#3604](https://github.com/ScoopInstaller/Scoop/issues/3604))

### Documentation

- **readme:** Improve installation instructions ([#3600](https://github.com/ScoopInstaller/Scoop/issues/3600))

## [2019-06-24](https://github.com/ScoopInstaller/Scoop/compare/2019-05-15...2019-06-24)

### Features

- **decompress:** Add 'ExtractDir' to 'Expand-...' functions ([#3466](https://github.com/ScoopInstaller/Scoop/issues/3466), [#3470](https://github.com/ScoopInstaller/Scoop/issues/3470), [#3472](https://github.com/ScoopInstaller/Scoop/issues/3472))
- **decompress:** Allow 'Expand-InnoArchive -ExtractDir' to accept '{xxx}' ([#3487](https://github.com/ScoopInstaller/Scoop/issues/3487))

### Bug Fixes

- **config:** Show correct output when removing a config value ([#3462](https://github.com/ScoopInstaller/Scoop/issues/3462))
- **decompress:** Change dark.exe parameter order ([6141e46d](https://github.com/ScoopInstaller/Scoop/commit/6141e46d6ae74b3ccf65e02a1c3fc92e1b4d3e7a))
- **proxy:** Rename parameters for Net.NetworkCredential ([#3483](https://github.com/ScoopInstaller/Scoop/issues/3483))

### Code Refactoring

- **core:**  `run()` -> 'Invoke-ExternalCommand()' ([#3432](https://github.com/ScoopInstaller/Scoop/issues/3432))

### Builds

- **checkhashes:** Checkhashes downloading twice when architecture properties does hot have url property ([#3479](https://github.com/ScoopInstaller/Scoop/issues/3479))
- **checkhashes:** Do not call scoop directly ([#3527](https://github.com/ScoopInstaller/Scoop/issues/3527))

### Documentation

- **readme:** Add known buckets to end of readme ([2849e0f9](https://github.com/ScoopInstaller/Scoop/commit/2849e0f96099004f761d7d8c715377e0d2c105f2))
- **readme:** Adjust URL of `runat.json` ([#3484](https://github.com/ScoopInstaller/Scoop/issues/3484))
- **readme:** Fix a small typo ([#3512](https://github.com/ScoopInstaller/Scoop/issues/3512))
- **readme:** Fix typo in readme ([03bb07c8](https://github.com/ScoopInstaller/Scoop/commit/03bb07c8231563fa3a2092b9b52d4dde372f2a8e))
- **readme:** Update readme with correct count of nirsoft apps ([e8d0be66](https://github.com/ScoopInstaller/Scoop/commit/e8d0be663b3bab25d9ee55c597b90bf922f4ec5d))

## [2019-05-15](https://github.com/ScoopInstaller/Scoop/compare/2019-05-12...2019-05-15)

### Features

- **manifest:** XPath support in checkver and autoupdate ([#3458](https://github.com/ScoopInstaller/Scoop/issues/3458))
- **update:** Support changing scoop tracking repository ([#3459](https://github.com/ScoopInstaller/Scoop/issues/3459))

### Bug Fixes

- **autoupdate:** Handle xml namespace in xpath mode ([#3465](https://github.com/ScoopInstaller/Scoop/issues/3465))

## [2019-05-12](https://github.com/ScoopInstaller/Scoop/releases/tag/2019-05-12)

### BREAKING CHANGE

- **core:** Finalize bucket extraction ([#3399](https://github.com/ScoopInstaller/Scoop/issues/3399))
- **core:** Bucket extraction and refactoring ([#3449](https://github.com/ScoopInstaller/Scoop/issues/3449))

### Features

- **autoupdate:** Add 'regex' alias for 'find' ([3453487e](https://github.com/ScoopInstaller/Scoop/commit/3453487ed65378cc9ba2efc658ed6bc1431ef463))
- **autoupdate:** Allow simple metalink and meta4 hash extraction ([ecf627c3](https://github.com/ScoopInstaller/Scoop/commit/ecf627c3b8493b3ccf7ddb882b0c946533774d76))
- **autoupdate:** Add version variables to autoupdate.hash.regex ([#2966](https://github.com/ScoopInstaller/Scoop/issues/2996))
- **autoupdate:** Autoupdate improvements ([#1371](https://github.com/ScoopInstaller/Scoop/issues/1371))
- **autoupdate:** Convert base64 encoded hash values ([04c9ddeb](https://github.com/ScoopInstaller/Scoop/commit/04c9ddeb6d3b99496c39543ad468d34f4f1adeff))
- **autoupdate:** Improve base64 hash detection ([310096e2](https://github.com/ScoopInstaller/Scoop/commit/310096e2386ff3bf9082d547b140a98b92b87a83))
- **core:** Add basic WSL support by appending .exe to powershell ([#2323](https://github.com/ScoopInstaller/Scoop/issues/2323))
- **core:** Add Expand-DarkArchive and some other dependency features ([#3450](https://github.com/ScoopInstaller/Scoop/issues/3450))
- **core:** Enable TLS 1.2 in core.ps1 ([#2074](https://github.com/ScoopInstaller/Scoop/issues/2074))
- **core:** Prepare extraction of main bucket ([#3060](https://github.com/ScoopInstaller/Scoop/issues/3060))
- **core:** Support loading basedirs from config ([#3121](https://github.com/ScoopInstaller/Scoop/issues/3121))
- **core:** Update requirement to version 5 or greater ([#3330](https://github.com/ScoopInstaller/Scoop/issues/3330))
- **core:** Use consistent User-Agent Header on all webrequests ([12962acf](https://github.com/ScoopInstaller/Scoop/commit/12962acfa853593e371d09186e51660aece331e5))
- **core:** Warn on shim overwrite ([#2033](https://github.com/ScoopInstaller/Scoop/issues/2033))
- **debug:** Add option to indent debug output ([bf54a978](https://github.com/ScoopInstaller/Scoop/commit/bf54a978a1bc2efcde52513a60ec5bcb7bb1a44e))
- **decompress:** Allow other args to be passthrough ([#3411](https://github.com/ScoopInstaller/Scoop/issues/3411))
- **download:** Add support for multi-connection downloads via aria2c ([#2312](https://github.com/ScoopInstaller/Scoop/issues/2312))
- **download:** Convert sourceforge urls to use downloads mirror ([#3340](https://github.com/ScoopInstaller/Scoop/issues/3340))
- **install:** Add .NET 4.5 check to scoop install script ([e52c24c9](https://github.com/ScoopInstaller/Scoop/commit/e52c24c94ec805a327440cc07aec699afc7cc308))
- **install:** Set file write permission to global persist dir ([#2524](https://github.com/ScoopInstaller/Scoop/issues/2524))
- **json:** Normalize multi-line strings to string arrays on format ([#2444](https://github.com/ScoopInstaller/Scoop/issues/2444))
- **persist:** Support persisting files without a file extension ([#2408](https://github.com/ScoopInstaller/Scoop/issues/2408))
- **shim:** Add '.com'-type shim ([#3366](https://github.com/ScoopInstaller/Scoop/issues/3366))
- **shim:** Enabled applications which require elevated privileges ([#2053](https://github.com/ScoopInstaller/Scoop/issues/2053))
- **shim:** Enabled shimming of external applications ([#2072](https://github.com/ScoopInstaller/Scoop/issues/2072))
- **shim:** Enabled wide characters forwarding in shims ([#2106](https://github.com/ScoopInstaller/Scoop/issues/2106))
- **shim:** Make shim support PowerShell 2.0 ([#2562](https://github.com/ScoopInstaller/Scoop/issues/2562))
- **shim:** Create sh shim ([#1951](https://github.com/ScoopInstaller/Scoop/issues/1951))
- **shortcuts:** Add subdirectories/arguments for shortcuts ([#1945](https://github.com/ScoopInstaller/Scoop/issues/1945))
- **shortcuts:** Allow $dir, $original_dir and $persist_dir substitutions for shortcuts ([f3ddf0c0](https://github.com/ScoopInstaller/Scoop/commit/f3ddf0c0f81ee2a11466edf5d9f6e38a0fc2b9d4))
- **shortcuts:** Get start menu folder location from environment rather than predefined user profile path ([c245a7fe](https://github.com/ScoopInstaller/Scoop/commit/c245a7fe96ffa0b0fba23bd47f31480ea93cc183))
- **uninstall:** Print purge step to console ([#3123](https://github.com/ScoopInstaller/Scoop/issues/3123))
- **uninstall:** Add support for soft/purge uninstalling of scoop itself ([#2781](https://github.com/ScoopInstaller/Scoop/issues/2781))
- **update:** Add hold/unhold command ([#3444](https://github.com/ScoopInstaller/Scoop/issues/3444))
- **scoop-checkup:** Add NTFS check to checkup command ([#1944](https://github.com/ScoopInstaller/Scoop/issues/1944))
- **scoop-checkup:** Check for LongPaths setting ([#3387](https://github.com/ScoopInstaller/Scoop/issues/3387))
- **scoop-info:** Add scoop-info command ([#2165](https://github.com/ScoopInstaller/Scoop/issues/2165))
- **scoop-info:** Support url manifest ([#2538](https://github.com/ScoopInstaller/Scoop/issues/2538))
- **scoop-prefix:** Add scoop prefix command ([#2117](https://github.com/ScoopInstaller/Scoop/issues/2117))
- **scoop-update:** Add notification for new main bucket ([#3392](https://github.com/ScoopInstaller/Scoop/issues/3392))
- **scoop-update:** Show changelog after updating scoop and buckets ([56c35f8f](https://github.com/ScoopInstaller/Scoop/commit/56c35f8f05ed387997ef1a80ec0362adec6e51a5))
- **scoop-which:** Also show other applications in PATH with 'scoop which' ([79bf99c3](https://github.com/ScoopInstaller/Scoop/commit/79bf99c3c110494d799e147263db7b6f2f921d4e))

### Bug Fixes

- **autoupdate:** Fix base64 hash extraction ([98afb999](https://github.com/ScoopInstaller/Scoop/commit/98afb99990561c4f98f1e1334f348e52b4bee4e7))
- **autoupdate:** Fix base64 hash extraction length ([#2852](https://github.com/ScoopInstaller/Scoop/issues/2852))
- **autoupdate:** Fix metalink hash extraction ([2ad54747](https://github.com/ScoopInstaller/Scoop/commit/2ad547477b1432e7a269c90b393d62d88dce9803))
- **autoupdate:** Fix single line hash extraction ([#3015](https://github.com/ScoopInstaller/Scoop/issues/3015))
- **autoupdate:** Improve auto-update hash extraction regex ([21bf0dea](https://github.com/ScoopInstaller/Scoop/commit/21bf0dea561db021aa59bcd9363792436ac7c162))
- **autoupdate:** Linter fix ([c9539b65](https://github.com/ScoopInstaller/Scoop/commit/c9539b6575e8842a8f895d82b4119c3aef01d7c2))
- **autoupdate:** Use normal variable instead of magic $matches variable name ([d74e0a85](https://github.com/ScoopInstaller/Scoop/commit/d74e0a85b4081745bd1ab107a45794f02299737d))
- **bucket:** Change wording of new_issue_msg() ([e82587df](https://github.com/ScoopInstaller/Scoop/commit/e82587dfc41618474e03347df333e847dfaffc70))
- **bucket:** Fix new_issue_msg ([#3375](https://github.com/ScoopInstaller/Scoop/issues/3375))
- **bucket:** Use $_.Name on gci result ([1eb2609d](https://github.com/ScoopInstaller/Scoop/commit/1eb2609db51587772a4b5d1b6f58114f52639568))
- **config:** Enable writing to hidden .scoop file ([#1982](https://github.com/ScoopInstaller/Scoop/issues/1982))
- **config:** Save and load true/false values as booleans in scoops config ([16aec1a4](https://github.com/ScoopInstaller/Scoop/commit/16aec1a40b45ba241ef2ac45ccf89de7206891be))
- **core:** Allowed underscores in package names ([#2930](https://github.com/ScoopInstaller/Scoop/issues/2930))
- **core:** Clean up some error messages ([#2032](https://github.com/ScoopInstaller/Scoop/issues/2032))
- **core:** Change sf regex not to break some manifests ([#2476](https://github.com/ScoopInstaller/Scoop/issues/2476))
- **core:** Check if 7zip installed via Scoop instead of using 7z.exe from PATH ([55ce0c0b](https://github.com/ScoopInstaller/Scoop/commit/55ce0c0b0c481ec3807655cb7aeac6dfcf9ef271))
- **core:** Filter null or empty string from Scoops directory settings ([5d5c7fa9](https://github.com/ScoopInstaller/Scoop/commit/5d5c7fa91c03f05b705d3420618ec96d8e870174))
- **core:** Fix "enable-encryptionscheme" for OSes before Windows 10 ([#2084](https://github.com/ScoopInstaller/Scoop/issues/2084))
- **core:** Fix bug with Start-Process -Wait, exclusive to PowerShell Core on Windows 7 ([#3415](https://github.com/ScoopInstaller/Scoop/issues/3415))
- **core:** Fix for relative paths ([ff9c0c3d](https://github.com/ScoopInstaller/Scoop/commit/ff9c0c3dafb3567ee958379b83205da84a925ecf))
- **core:** Fix robocopy not releasing a directory after moving it ([e2792f2e](https://github.com/ScoopInstaller/Scoop/commit/e2792f2e02adee5947ebb95022a62282fb61024f))
- **core:** Fix substitute() for arrays ([#2048](https://github.com/ScoopInstaller/Scoop/issues/2048))
- **core:** Format hashes to lowercase ([5d56f8ff](https://github.com/ScoopInstaller/Scoop/commit/5d56f8ff5760ddedaf44eaf9652000e833b0944e))
- **core:** Invoke powershell with -noprofile flag from bash shims ([#3165](https://github.com/ScoopInstaller/Scoop/issues/3165))
- **core:** Removed the bucket from the app name when checking directories ([#2435](https://github.com/ScoopInstaller/Scoop/issues/2435))
- **core:** Return true for checking if a directory is 'in' itself ([ac8a1567](https://github.com/ScoopInstaller/Scoop/commit/ac8a156796cb6d3d9cba24a2839271d924ab8fea))
- **core:** Store last update time as String ([e8af15cc](https://github.com/ScoopInstaller/Scoop/commit/e8af15cc0615b707aee79be95f9c00e3ae0bfd9b))
- **decompress:** Add .bz2 files to decompression ([#2085](https://github.com/ScoopInstaller/Scoop/issues/2085))
- **decompress:** Added retry when unzip fail because of AV ([#1822](https://github.com/ScoopInstaller/Scoop/issues/1822))
- **decompress:** Catch unzip failures from bad file names ([#2472](https://github.com/ScoopInstaller/Scoop/issues/2472))
- **decompress:** Compatible Expand-ZipArchive() with Pscx ([#3425](https://github.com/ScoopInstaller/Scoop/issues/3425))
- **decompress:** Correct deprecation function name ([#3406](https://github.com/ScoopInstaller/Scoop/issues/3406))
- **decompress:** Fix dark parameter order ([87a1e784](https://github.com/ScoopInstaller/Scoop/commit/87a1e784d7463fea36fa41fcb7cb5537cbcfdc52))
- **depends:** Don't force adding dark dependency ([#3453](https://github.com/ScoopInstaller/Scoop/issues/3453))
- **depends:** Don't include the requested app in the list of dependencies ([1bc6a479](https://github.com/ScoopInstaller/Scoop/commit/1bc6a479ee969e44e2b0d83ed6ff19efd86c6ae9))
- **depends:** Fix empty bucket name ([#2827](https://github.com/ScoopInstaller/Scoop/issues/2827))
- **depends:** Fix null reference error when no buckets are configured ([88040972](https://github.com/ScoopInstaller/Scoop/commit/88040972a30b459a3859c7c2f883e47e19da9f84))
- **depends:** Show message about missing bucket when installing dependencies ([7a6218c5](https://github.com/ScoopInstaller/Scoop/commit/7a6218c58677170fe32cf1c2bfcfe7488e4c3655))
- **download:** Don't send referer to portableapps.com ([0c2b3da3](https://github.com/ScoopInstaller/Scoop/commit/0c2b3da3ff639722ad3ddf587219bb3155e97c7f))
- **download:** Fix fosshub downloads with aria2c ([803525a8](https://github.com/ScoopInstaller/Scoop/commit/803525a8661ffaa39fc4ad6f0dc776cccad4c45e))
- **download:** Interrupt download causes partial cache file to be used for next install ([5be02865](https://github.com/ScoopInstaller/Scoop/commit/5be0286561398debfee2c0610e51f006ef2dc2fb))
- **download:** Overwrite any existing files when extracting ([58cca68f](https://github.com/ScoopInstaller/Scoop/commit/58cca68f7565bd5e8f63e08ad052c0029b98a23d))
- **download:** Show warning about SourceForge.net hash validation fails ([8504338b](https://github.com/ScoopInstaller/Scoop/commit/8504338bc5faab3235cef2e1c2f41abd7ae496eb))
- **getopt:** Don't try to parse int arguments ([23fe5a53](https://github.com/ScoopInstaller/Scoop/commit/23fe5a5319d4ede84c532df04f576c3854fd5826))
- **getopt:** Don't try to parse array arguments ([9b6e7b5e](https://github.com/ScoopInstaller/Scoop/commit/9b6e7b5e0f7f6ddecdb139f932ad7d582fe639a4))
- **getopt:** Return remaining args, use getopt for scoop install ([b7cfd6fd](https://github.com/ScoopInstaller/Scoop/commit/b7cfd6fdb0e18a623ceacfa6fc824241dabc6d01))
- **getopt:** Skip if arg is $null ([f2d9f0d7](https://github.com/ScoopInstaller/Scoop/commit/f2d9f0d79fdf4a63879c1b87a6c0f5317a40a1d9))
- **getopt:** Skip arg if it's decimal ([5f0c8cfb](https://github.com/ScoopInstaller/Scoop/commit/5f0c8cfb0a34078bb8118a21191cf046ddad18ac))
- **git:** Disable git pager when running git log ([cac99759](https://github.com/ScoopInstaller/Scoop/commit/cac9975924691fe6e608789218b06be56bb8c658))
- **git:** Fix update log output ([0daa25c6](https://github.com/ScoopInstaller/Scoop/commit/0daa25c6300cd2ab605d63b71037d741c9c904c6))
- **json:** Catch JsonReaderException ([fb58e92c](https://github.com/ScoopInstaller/Scoop/commit/fb58e92c13552199f19f5df112801fc41321eee2))
- **install:** Add filename to warning for files without hash in the manifest ([4c9beee8](https://github.com/ScoopInstaller/Scoop/commit/4c9beee8f2df891b2ec314e1efffb2ee9d5cca20))
- **install:** Add multi-line support to pre/post_install ([#1980](https://github.com/ScoopInstaller/Scoop/issues/1980))
- **install:** Added exclusion for sourceforge. [#METR-21516] ([#2109](https://github.com/ScoopInstaller/Scoop/issues/2109))
- **install:** Ignore url fragment for PowerShell Core 6.1.0 ([#2602](https://github.com/ScoopInstaller/Scoop/issues/2602))
- **install:** Fix fail when installing from non-default bucket ([#2247](https://github.com/ScoopInstaller/Scoop/issues/2247))
- **install:** Fix PowerShell core crash ([#2554](https://github.com/ScoopInstaller/Scoop/issues/2554))
- **install:** Option to skip hash validation and error message improvements ([#2260](https://github.com/ScoopInstaller/Scoop/issues/2260))
- **install:** Remove env_ensure_home ([#1967](https://github.com/ScoopInstaller/Scoop/issues/1967))
- **install:** Show first 8 bytes of file in the hash check error message ([e4cbb42e](https://github.com/ScoopInstaller/Scoop/commit/e4cbb42e64843e53b5b24de92f43062bca98c474))
- **persist:** Fix condition for persist_permission() ([eb7b7cbf](https://github.com/ScoopInstaller/Scoop/commit/eb7b7cbf4f30e4122762856723155f3c1e980d1b)) ([1a2598bc](https://github.com/ScoopInstaller/Scoop/commit/1a2598bc3082a2e3fffac1a6bea0b42032e388f0))
- **persist:** Fixed persisting bug when force update app with same version ([#2774](https://github.com/ScoopInstaller/Scoop/issues/2774))
- **persist:** Fix the target didn't be created ([#3008](https://github.com/ScoopInstaller/Scoop/issues/3008))
- **persist:** Prevent directory creation from being output ([#1999](https://github.com/ScoopInstaller/Scoop/issues/1999))
- **scoop:** Force to add new main bucket ([#3419](https://github.com/ScoopInstaller/Scoop/issues/3419))
- **shim:** Fix .ps1 shim parsing logic ([#2564](https://github.com/ScoopInstaller/Scoop/issues/2564))
- **shim:** Fixed ps1/jar->ps1 shims args handling ([#2120](https://github.com/ScoopInstaller/Scoop/issues/2120))
- **shortcuts:** Improve Shortcut creation ([83b82386](https://github.com/ScoopInstaller/Scoop/commit/83b823868f5ef5256d3dcfbecff278bb355fefc8))
- **uninstall:** Better error handling during uninstallation ([#2079](https://github.com/ScoopInstaller/Scoop/issues/2079))
- **uninstall:** Uninstall fails to remove architecture-specific shims ([8b1871b2](https://github.com/ScoopInstaller/Scoop/commit/8b1871b20df4dbf1b603d4066937ba213c03bb32))
- **update:** Rewording PowerShell update notice ([d006fb93](https://github.com/ScoopInstaller/Scoop/commit/d006fb9315b55a9d8e6a36218cf5dbdde51433ec))
- **versions:** Improvements for the reset command to deal with empty current alias dir correctly ([#2896](https://github.com/ScoopInstaller/Scoop/issues/2896))
- **scoop-alias:** Improve "scoop alias list" output ([#2163](https://github.com/ScoopInstaller/Scoop/issues/2163))
- **scoop-cache:** Display help on incorrect cache command ([#3431](https://github.com/ScoopInstaller/Scoop/issues/3431))
- **scoop-cache:** scoop cache command not using $SCOOP_CACHE ([#1990](https://github.com/ScoopInstaller/Scoop/issues/1990))
- **scoop-info:** Improve scoop-info license attributes output ([#2397](https://github.com/ScoopInstaller/Scoop/issues/2397))
- **scoop-install:** Prevent installing programs from JSON multiple times ([936cf9cb](https://github.com/ScoopInstaller/Scoop/commit/936cf9cbb0c4dd3a594fbaf5c696ce519e586d8c))
- **scoop-reset:** Persist data on reset ([#2773](https://github.com/ScoopInstaller/Scoop/issues/2773))
- **scoop-reset:** Re-create shortcuts ([6e5b7e57](https://github.com/ScoopInstaller/Scoop/commit/6e5b7e57bb0628f072872d9a5b8c8a0fa58389e1))
- **scoop-search:** Better handling for invalid query ([bf024705](https://github.com/ScoopInstaller/Scoop/commit/bf024705a8cc38592571aa3026dca2471f19ac5a))
- **scoop-uninstall:** Checked if uninstaller removed its directory ([#2078](https://github.com/ScoopInstaller/Scoop/issues/2078))
- **scoop-update:** Add config option "show_update_log" ([d68cb3ce](https://github.com/ScoopInstaller/Scoop/commit/d68cb3ce52acaa9983f278822febd506f54ebe02))
- **scoop-update:** First scoop update fails because scoop deletes itself too early ([376630fd](https://github.com/ScoopInstaller/Scoop/commit/376630fd80a3f9012fd6e673460b9e28e375e951))
- **scoop-update:** Fix branch switching ([#3372](https://github.com/ScoopInstaller/Scoop/issues/3372))
- **scoop-update:** Fix update with cookies ([#3261](https://github.com/ScoopInstaller/Scoop/issues/3261))
- **scoop-update:** Improve is_scoop_outdated() and add last_scoop_update() ([f3f559c4](https://github.com/ScoopInstaller/Scoop/commit/f3f559c460406689dab2375310fb1026e2be58bd))
- **scoop-update:** Resolve linting, fix appveyor tests error ([#2148](https://github.com/ScoopInstaller/Scoop/issues/2148))

### Code Refactoring

- **bucket:** Move function into lib from lib-exec ([#3062](https://github.com/ScoopInstaller/Scoop/issues/3062))
- **bucket:** Optimize buckets function ([#3341](https://github.com/ScoopInstaller/Scoop/issues/3341))
- **config:** Move configuration handling to core.ps1 ([#3242](https://github.com/ScoopInstaller/Scoop/issues/3242))
- **core:** aria2_path() -> file_path() ([0f464016](https://github.com/ScoopInstaller/Scoop/commit/0f4640168da8d68a52eb2b80af2f3ffa01c9b658))
- **core:** cmd_available() -> Test-CommandAvailable() ([#3314](https://github.com/ScoopInstaller/Scoop/issues/3314))
- **core:** ensure_all_installed() -> Confirm-InstallationStatus() ([#3293](https://github.com/ScoopInstaller/Scoop/issues/3293))
- **core:** Move default_aliases into the scoped function ([#3233](https://github.com/ScoopInstaller/Scoop/issues/3233))
- **core:** Refactor function names and fix installing 7zip locally if already globally available ([#3416](https://github.com/ScoopInstaller/Scoop/issues/3416))
- **core:** Simplified last_scoop_update() ([#2931](https://github.com/ScoopInstaller/Scoop/issues/2931))
- **core:** Tweak SecurityProtocol usage ([#3065](https://github.com/ScoopInstaller/Scoop/issues/3065))
- **decompress:** Refactored (w/ install.ps1, core.ps1) ([#3169](https://github.com/ScoopInstaller/Scoop/issues/3169))
- **decompress:** Refactor extraction handling functions ([#3204](https://github.com/ScoopInstaller/Scoop/issues/3204))
- **download:** Download functionality refactor ([#1329](https://github.com/ScoopInstaller/Scoop/issues/1329))
- **install:** Rename locate() to Find-Manifest() ([9eed3d89](https://github.com/ScoopInstaller/Scoop/commit/9eed3d8914c7a0fa294110eb0761776a01adf034))

### Builds

- **auto-pr:** Add -App parameter ([#3157](https://github.com/ScoopInstaller/Scoop/issues/3157))
- **auto-pr:** Add SkipUpdated parameter ([#3168](https://github.com/ScoopInstaller/Scoop/issues/3168))
- **checkhashes:** Add bin\checkhashes.ps1 ([#2766](https://github.com/ScoopInstaller/Scoop/issues/2766))
- **checkurls:** Add SkipValid Parameter ([#2845](https://github.com/ScoopInstaller/Scoop/issues/2845))
- **checkurls:** Import config.ps1 in checkurls.ps1 ([126e9c97](https://github.com/ScoopInstaller/Scoop/commit/126e9c97d2ef7db537a5137167089a97f343e98e))
- **checkver:** Add 'useragent' property ([8feb3867](https://github.com/ScoopInstaller/Scoop/commit/8feb3867a74ea0340585e3e695934d96cf483a05))
- **checkver:** Add 'jsonpath' alias for 'jp' ([76fdb6b7](https://github.com/ScoopInstaller/Scoop/commit/76fdb6b74c1772bf607d2dad5f6c50269369ff88))
- **checkver:** Add 're' alias 'regex' ([468649c8](https://github.com/ScoopInstaller/Scoop/commit/468649c88dea9c1ff9614f2cdf29a521d572664e))
- **checkver:** Allow using the current version in checkver URL ([607ac9ca](https://github.com/ScoopInstaller/Scoop/commit/607ac9ca7c185da61e2c746ea87d28c2abe62adc))
- **checkver:** Fix example parameters ([#3413](https://github.com/ScoopInstaller/Scoop/issues/3413))
- **checkver:** GitHub checkver case-insensitive version check ([2e2633e9](https://github.com/ScoopInstaller/Scoop/commit/2e2633e9640f6cab5c2f895b680345cd6ca))
- **checkver:** Remove old commented code ([72754036](https://github.com/ScoopInstaller/Scoop/commit/72754036a251fffd2f2eb0e242edfd9895543e3c))
- **checkver:** Resolve issue on Powershell >6.1.0 ([#2592](https://github.com/ScoopInstaller/Scoop/issues/2592))
- **checkver:** Support skipping up to date manifests ([#2624](https://github.com/ScoopInstaller/Scoop/issues/2624))
- **schema:** Add shortcutsArray definition to schema.json ([0c7e6002](https://github.com/ScoopInstaller/Scoop/commit/0c7e60024a06e122331b17a204a158e4c5800a3d))
- **schema:** extract_to property is on active duty (not deprecated) ([59e994c5](https://github.com/ScoopInstaller/Scoop/commit/59e994c5fdeb8dffe6037ca6767d56ad13bf04da))
- **schema:** Improve comments in schema.json ([b5ed0761](https://github.com/ScoopInstaller/Scoop/commit/b5ed0761aef4f3e864533dc0460d110115850ba7))
- **supporting:** Update validator.exe and shim.exe ([#2024](https://github.com/ScoopInstaller/Scoop/issues/2024), [#2034](https://github.com/ScoopInstaller/Scoop/issues/2034))
- **supporting:** Update Newtonsoft.Json to 11.0.2, Newtonsoft.Json.Schema to 3.0.10 ([#3043](https://github.com/ScoopInstaller/Scoop/issues/3043))
- **validator:** Improve error reporting, add support for multiple files ([#3134](https://github.com/ScoopInstaller/Scoop/issues/3134))

### Continuous Integration

- **appveyor:** Rebuild cache ([7311b41b](https://github.com/ScoopInstaller/Scoop/commit/7311b41b8d1e2e010175fb7d079662bbcba5bac8))
- **appveyor:** Run tests for PowerShell 5 and 6 ([#2603](https://github.com/ScoopInstaller/Scoop/issues/2603))
- **test:** Improve installation of lessmsi and innounp ([#3409](https://github.com/ScoopInstaller/Scoop/issues/3409))

### Styles

- **lint:** PSAvoidUsingCmdletAliases ([#2075](https://github.com/ScoopInstaller/Scoop/issues/2075))

### Tests

- **bucket:** Add importable tests for Buckets ([478f52c4](https://github.com/ScoopInstaller/Scoop/commit/478f52c421ca35ea35b5fd0b2df2631cf7d82487))
- **bucket:** Fix manifest tests for buckets ([589303fa](https://github.com/ScoopInstaller/Scoop/commit/589303facc5284f6f95c1305191e0558c0169691))
- **bucket:** Handle JSON.NET schema validation limit exceeded. ([139813a8](https://github.com/ScoopInstaller/Scoop/commit/139813a8f50ace85e2752d9b6c9f82fc64ff3e48))
- **file:** Move style constraints tests to separate test file ([7b7113fc](https://github.com/ScoopInstaller/Scoop/commit/7b7113fc3bf962aaeba625f58341c30a80f0fe6a))
- **linux:** Fix some tests on linux ([#2153](https://github.com/ScoopInstaller/Scoop/issues/2153))
- **manifest:** Expose bucketdir variable in manifest test script ([#2182](https://github.com/ScoopInstaller/Scoop/issues/2182))
- **test:** Add -TestPath param to test.ps1 ([f857dce9](https://github.com/ScoopInstaller/Scoop/commit/f857dce9f59a490f6dd07085c3abaa51e9577fda))
- **test:** Force install PSScriptAnalyzer and BuildHelpers ([7a1b5a18](https://github.com/ScoopInstaller/Scoop/commit/7a1b5a1840e30321951fa0f5333c34d10f57fa94))
- **test:** Require BuildHelpers version 2.0.0 ([ac3ee766](https://github.com/ScoopInstaller/Scoop/commit/ac3ee766722e99c1f15dc60a1f1dfb0a48428c55))
- **test:** Update BuildHelpers to version 2.0.1 ([dde4d0f9](https://github.com/ScoopInstaller/Scoop/commit/dde4d0f93f260191af5524c0ecab927f3e252361))
- **core:** Use Pester 4.0 syntax in core tests ([#2712](https://github.com/ScoopInstaller/Scoop/issues/2712))
- **install:** Use Pester 4.0 syntax to the install tests ([#2713](https://github.com/ScoopInstaller/Scoop/issues/2713))
- **test:** Use Pester 4.0 syntax to multiple files ([#2714](https://github.com/ScoopInstaller/Scoop/issues/2714))

### Documentation

- **readme:** Add discord chat badge ([#3241](https://github.com/ScoopInstaller/Scoop/issues/3241))
- **readme:** Add more details about scoops installation ([#2273](https://github.com/ScoopInstaller/Scoop/issues/2273))
- **readme:** Corrected enable powershell executionpolicy ([#2020](https://github.com/ScoopInstaller/Scoop/issues/2020))
- **readme:** Update Discord invite link ([5f269249](https://github.com/ScoopInstaller/Scoop/commit/5f269249609b43f5c4fa9aba4def999e7ee05fe1))
- **readme:** Update requirements note ([#2509](https://github.com/ScoopInstaller/Scoop/issues/2509))
- **readme:** Fix typo (you -> your), (it's -> its) ([#2698](https://github.com/ScoopInstaller/Scoop/issues/2698))
- **readme:** Remove trailing whitespaces ([d25186bf](https://github.com/ScoopInstaller/Scoop/commit/d25186bf1f833e30d8c5b530b7c260fe399b75ed))
- **readme:** Remove "tail" from example (is coreutils) ([#2158](https://github.com/ScoopInstaller/Scoop/issues/2158))

## *Commits before 2018 are trimmed*
