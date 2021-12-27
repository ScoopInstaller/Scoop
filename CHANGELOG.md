<a name="unreleased"></a>
## [Unreleased]

### Bug Fixes

- **depends:** Prevent error on no URL ([#4595](https://github.com/ScoopInstaller/Scoop/issues/4595))

<a name="2021-12-26"></a>
## [2021-12-26]

### Features

- **cli:** Add `scoop cat` command ([#4532](https://github.com/ScoopInstaller/Scoop/issues/4532))
- **checkver:** Improve JSONPath extraction support ([#4522](https://github.com/ScoopInstaller/Scoop/issues/4522))
- **checkver:** Use GitHub token from environment ([#4557](https://github.com/ScoopInstaller/Scoop/issues/4557))
- **core:** Redirect 'StandardError' in `Invoke-ExternalCommand()` ([#4570](https://github.com/ScoopInstaller/Scoop/issues/4570))
  - **decompress:** Fix 'Expand-7zipArchive()' for nested archive ([#4582](https://github.com/ScoopInstaller/Scoop/issues/4582))
- **install:** Add portableapps.com to strip_filename skips ([#3244](https://github.com/ScoopInstaller/Scoop/issues/3244))
- **install:** Show manifest on installation ([#4155](https://github.com/ScoopInstaller/Scoop/issues/4155))
  - **install:** Show manifest name while reviewing ([fb496c48](https://github.com/ScoopInstaller/Scoop/commit/fb496c482bec4063e01b328f943224ab703dbbd8))
  - **install:** Don't show manifest while updating ([#4581](https://github.com/ScoopInstaller/Scoop/issues/4581))
- **schema:** Enable autoupdate for 'license' ([#4528](https://github.com/ScoopInstaller/Scoop/issues/4528))
  - **schema:** Add 'license' definition ([#4596](https://github.com/ScoopInstaller/Scoop/issues/4596))
- **template:** Add issue/PR templates ([#4572](https://github.com/ScoopInstaller/Scoop/issues/4572))
- **scoop-config:** Document all configuration options ([#4579](https://github.com/ScoopInstaller/Scoop/issues/4579))

### Bug Fixes

- **auto-pr:** Remove hardcoded 'master' branch ([#4567](https://github.com/ScoopInstaller/Scoop/issues/4567))
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

- **shim:** Rework shimming logic ([#4543](https://github.com/ScoopInstaller/Scoop/issues/4543))
  - **shim:** Hotfix for PS1 shim([#4555](https://github.com/ScoopInstaller/Scoop/issues/4555))
  - **shim:** Specify command arg ([3c90d1a0](https://github.com/ScoopInstaller/Scoop/commit/3c90d1a0701b0b64730dbf9ebc8d31f9b9c238f1))
  - **shim:** Specify command arg for bash ([2ec00d57](https://github.com/ScoopInstaller/Scoop/commit/2ec00d576c7e594dc5c0f1eac4536c5310ce6f17))

### Documentation

- **readme:** Add link to Contributing Guide ([5e11c94a](https://github.com/ScoopInstaller/Scoop/commit/5e11c94a544ff2adbdbec5072c32a94d3e5acb9c))
- **readme:** Fix links ([3bb7036e](https://github.com/ScoopInstaller/Scoop/commit/3bb7036ee111bfe58e82ba3d0fd39189b058776a))

### Reverts

- **shim:** Revert [#4229](https://github.com/ScoopInstaller/Scoop/issues/4229) ([#4553](https://github.com/ScoopInstaller/Scoop/issues/4553))

<a name="2021-11-22"></a>
## [2021-11-22]

### Features

- **autoupdate:** Add multiple URL/hash/extract_dir... support ([#3518](https://github.com/ScoopInstaller/Scoop/issues/3518))
  - **autoupdate:** Update array of arrays correctly ([#4502](https://github.com/ScoopInstaller/Scoop/issues/4502))
- **bucket:** Move extras bucket to [@ScoopInstaller](https://github.com/ScoopInstaller) ([3e9a4d4e](https://github.com/ScoopInstaller/Scoop/commit/3e9a4d4ea0e7e4d6489099c46a763f58db07e633))
- **decompress:** Support Zstandard archive ([#4372](https://github.com/ScoopInstaller/Scoop/issues/4372))
  - **decompress:** Check `.zst` first ([e35ff313](https://github.com/ScoopInstaller/Scoop/commit/e35ff313a5d35cab1049024938c3423a5f6bf060))
  - **test:** Use 32bit version of `zstd` ([47ebc6f1](https://github.com/ScoopInstaller/Scoop/commit/47ebc6f176b0db0afeb51b4ee237a20b2d8649e9))
- **install:** Handle arch-specific env_add_path ([#4013](https://github.com/ScoopInstaller/Scoop/issues/4013))
- **install:** s/lukesamson/ScoopInstaller in install.ps1 ([5226f26f](https://github.com/ScoopInstaller/Scoop/commit/5226f26f18157ed78f1529144404ec682374452e))
- **message:** Add config to disable aria2 warning message ([#4422](https://github.com/ScoopInstaller/Scoop/issues/4422))
- **shim:** Add another alternative shim written in rust ([#4229](https://github.com/ScoopInstaller/Scoop/issues/4229))
- **supporting:** Update Json to 12.0.3, Json.Schema to 3.0.14 ([#3352](https://github.com/ScoopInstaller/Scoop/issues/3352))
- **scoop-prefix:** Remove unused imports and functions ([#4494](https://github.com/ScoopInstaller/Scoop/issues/4494))
- **scoop-install:** Auto uninstall previous failed installation ([#3281](https://github.com/ScoopInstaller/Scoop/issues/3281))
- **scoop-update:** Add flags `--all` as an alternative to '*' to update all ([#3871](https://github.com/ScoopInstaller/Scoop/issues/3871))

### Bug Fixes

- **core:** Change url() scope to avoid conflict with global aliases ([#4342](https://github.com/ScoopInstaller/Scoop/issues/4342))
  - **core:** Use `script:url` instead of `url` ([#4492](https://github.com/ScoopInstaller/Scoop/issues/4492))
- **install:** Fix `aria2`'s resume download feature ([#3292](https://github.com/ScoopInstaller/Scoop/issues/3292))
- **schema:** Fix Schema to support `+` in version ([#4504](https://github.com/ScoopInstaller/Scoop/issues/4504))
- **shim:** Fixed trailing whitespace issue ([#4307](https://github.com/ScoopInstaller/Scoop/issues/4307))
- **scoop-reset:** Skip when app instance is running ([#4359](https://github.com/ScoopInstaller/Scoop/issues/4359))

### Code Refactoring

- **versions:** Refactor 'versions.ps1' ([#3721](https://github.com/ScoopInstaller/Scoop/issues/3721))
  - **test:** Add more test cases for versions ([e6630272](https://github.com/ScoopInstaller/Scoop/commit/e663027299d03ca768a252fa4bcbc51d124d4cae))
  - **versions:** Fix situation that contains '_' ([ae892138](https://github.com/ScoopInstaller/Scoop/commit/ae892138423bb9bbf54c8f0bed8331b93199f6b8))

### Documentation

- **readme:** Capitalize to prevent redirect ([#4483](https://github.com/ScoopInstaller/Scoop/issues/4483))
- **readme:** s/lukesampson/ScoopInstaller in readme ([4f5acd72](https://github.com/ScoopInstaller/Scoop/commit/4f5acd72109a98a148d1bfa269c23a2d43644d23))
- **readme:** Update extras bucket url in readme ([f1a46e10](https://github.com/ScoopInstaller/Scoop/commit/f1a46e109596c55c7e83c77fc1fc9daedbe71636))
- **readme:** Update Java bucket text ([#4514](https://github.com/ScoopInstaller/Scoop/issues/4514))
- **readme:** Update notes about the NirSoft bucket ([#4524](https://github.com/ScoopInstaller/Scoop/issues/4524))

<a name="2020-11-26"></a>
## [2020-11-26]

### Bug Fixes

- **shim:** Fix Makefile typo ([0948824e](https://github.com/ScoopInstaller/Scoop/commit/0948824ec7269c979882d09342d9a269193cd674)) ([227de6cf](https://github.com/ScoopInstaller/Scoop/commit/227de6cfb8433a86ac0f0a279e691327ae04554c))

<a name="2020-10-22"></a>
## [2020-10-22]

### Features

- **aria2:** Inline progress ([#3987](https://github.com/ScoopInstaller/Scoop/issues/3987))
- **autoupdate:** Add $urlNoExt and $basenameNoExt substitutions ([#3742](https://github.com/ScoopInstaller/Scoop/issues/3742))
- **scoop-checkup:** Add check_envs_requirements ([#3860](https://github.com/ScoopInstaller/Scoop/issues/3860))
- **checkver:** Present script property ([#3900](https://github.com/ScoopInstaller/Scoop/issues/3900))
- **config:** Add configuration option for default architecture ([#3778](https://github.com/ScoopInstaller/Scoop/issues/3778))
- **install:** Follow HTTP redirections when downloading a file ([#3902](https://github.com/ScoopInstaller/Scoop/issues/3902))
- **install:** Let pathes in 'env_add_path' be added ascendantly ([#3788](https://github.com/ScoopInstaller/Scoop/issues/3788))
  - **install:** `[Array]::Reverse` error ([#3976](https://github.com/ScoopInstaller/Scoop/issues/3976))
- **list:** Display main bucket name ([#3759](https://github.com/ScoopInstaller/Scoop/issues/3759))
- **shim:** Add alt-shim support ([#3998](https://github.com/ScoopInstaller/Scoop/issues/3998))

### Bug Fixes

- **bucket:** Update scoop-nonportable URL ([#3776](https://github.com/ScoopInstaller/Scoop/issues/3776))
- **download:** Fosshub download ([#4051](https://github.com/ScoopInstaller/Scoop/issues/4051))
- **download:** Progress bar on small files ([96de9c14](https://github.com/ScoopInstaller/Scoop/commit/96de9c14bb483f9278e4b0a9e22b1923ee752901))
- **hold:** Replace "locked" terminology with "held" for consistency ([#3917](https://github.com/ScoopInstaller/Scoop/issues/3917))
- **git:** Don't execute autostart programs when executing git commands ([#3993](https://github.com/ScoopInstaller/Scoop/issues/3993))
- **git:** Enforce pull without rebase ([#3765](https://github.com/ScoopInstaller/Scoop/issues/3765))
- **install:** Aria2 inline progress negative values ([#4053](https://github.com/ScoopInstaller/Scoop/issues/4053))
- **install:** Fix wrong output of 'install/failed' ([#3784](https://github.com/ScoopInstaller/Scoop/issues/3784))
  - **install:** Fix 'failed' function ([#3867](https://github.com/ScoopInstaller/Scoop/issues/3867))
- **install:** Re-add "Don't send referer to portableapps.com" ([#3961](https://github.com/ScoopInstaller/Scoop/issues/3961))
- **scoop:** Remove temporary code from the scoop executable ([#3898](https://github.com/ScoopInstaller/Scoop/issues/3898))
- **tests:** Force pester v4 ([#4040](https://github.com/ScoopInstaller/Scoop/issues/4040))
- **update:** Update outdated PowerShell 5 warning ([#3986](https://github.com/ScoopInstaller/Scoop/issues/3986))
- **scoop-info:** Check bucket of installed app ([#3740](https://github.com/ScoopInstaller/Scoop/issues/3740))

<a name="2019-10-23"></a>
## [2019-10-23]

### Features

- **update:** Support $persist_dir in uninstaller.script ([#3692](https://github.com/ScoopInstaller/Scoop/issues/3692))

### Bug Fixes

- **core:** Use [Environment]::Is64BitOperatingSystem instead of [intptr]::size ([#3690](https://github.com/ScoopInstaller/Scoop/issues/3690))
- **git:** Remove unnecessary git_proxy_cmd() calls for local commands ([8ee45a57](https://github.com/ScoopInstaller/Scoop/commit/8ee45a57dc01a525dcf8776bf9bb45263992c81f))
- **install:** Check execution policy ([#3619](https://github.com/ScoopInstaller/Scoop/issues/3619))
- **update:** Fix scoop update changelog output ([e997017f](https://github.com/ScoopInstaller/Scoop/commit/e997017f1a03e2eefef2157acdfefe2e4fced896))

<a name="2019-10-18"></a>
## [2019-10-18]

### Features

- **core:** Tweak Invoke-ExternalCommand parameters ([#3547](https://github.com/ScoopInstaller/Scoop/issues/3547))
- **install:** Use 7zip when available for faster zip file extraction ([#3460](https://github.com/ScoopInstaller/Scoop/issues/3460))
- **install:** Add arch support to `env_add_path` and `env_set` ([#3503](https://github.com/ScoopInstaller/Scoop/issues/3503))
- **install:** Allow $version to be used in uninstaller scripts ([#3592](https://github.com/ScoopInstaller/Scoop/issues/3592))
- **install:** Allow installing specific version if latest is installed ([11c42d78](https://github.com/ScoopInstaller/Scoop/commit/11c42d782f8adb29fbe0d94daa5f121cdda935ab))
- **tests:** Do not force maintainers to have SCOOP_HELPERS ([#3604](https://github.com/ScoopInstaller/Scoop/issues/3604))
- **update:** Allow updating apps from local manifest or URL ([#3685](https://github.com/ScoopInstaller/Scoop/issues/3685))

### Bug Fixes

- **auto-pr:** Fix git status detection ([7decfd4c](https://github.com/ScoopInstaller/Scoop/commit/7decfd4c107b8d8a59d7eedfe8a56e1801120c2f))
- **auto-pr:** Hard reset bucket after running ([79f8538b](https://github.com/ScoopInstaller/Scoop/commit/79f8538b57b9021db71a279879b9032fefd1ae52))
- **autoupdate:** Decode basename when extract hash ([#3615](https://github.com/ScoopInstaller/Scoop/issues/3615))
- **autoupdate:** Remove any whitespace from hash ([#3579](https://github.com/ScoopInstaller/Scoop/issues/3579))
- **bucket:** Only lookup directories in buckets folder ([#3631](https://github.com/ScoopInstaller/Scoop/issues/3631))
- **checkurls:** Trim renaming suffix in url ([#3677](https://github.com/ScoopInstaller/Scoop/issues/3677))
- **comspec:** Escape variables when calling COMSPEC commands ([#3538](https://github.com/ScoopInstaller/Scoop/issues/3538))
- **decompress:** Fix bugs on extract_dir ([#3540](https://github.com/ScoopInstaller/Scoop/issues/3540))
- **editorconfig:** Add missing } to bat/cmd regex ([#3529](https://github.com/ScoopInstaller/Scoop/issues/3529))
- **help:** Rename help() to scoop_help() ([#3564](https://github.com/ScoopInstaller/Scoop/issues/3564))
- **install:** Use Join-Path instead of string gluing. ([#3566](https://github.com/ScoopInstaller/Scoop/issues/3566))
- **scoop-info:** Fix output for single binaries with alias ([#3651](https://github.com/ScoopInstaller/Scoop/issues/3651))
- **scoop-info:** Remove a whitespace ([#3652](https://github.com/ScoopInstaller/Scoop/issues/3652))

### Continuous Integration

- **appveyor:** use VS2019 image to fix PS6 issues ([#3646](https://github.com/ScoopInstaller/Scoop/issues/3646))

### Documentation

- **readme:** Improve installation instructions ([#3600](https://github.com/ScoopInstaller/Scoop/issues/3600))

<a name="2019-06-24"></a>
## [2019-06-24]

### Features

- **decompress:** Add 'ExtractDir' to 'Expand-...' functions ([#3466](https://github.com/ScoopInstaller/Scoop/issues/3466))
  - **decompress:** '$ExtractDir' removed original extract file by accident ([#3470](https://github.com/ScoopInstaller/Scoop/issues/3470))
  - **decompress:** '$ExtractDir' error with '.zip' and subdir ([#3472](https://github.com/ScoopInstaller/Scoop/issues/3472))
- **decompress:** Allow 'Expand-InnoArchive -ExtractDir' to accept '{xxx}' ([#3487](https://github.com/ScoopInstaller/Scoop/issues/3487))

### Bug Fixes

- **bin:** Checkhashes downloading twice when architecture properties does hot have url property ([#3479](https://github.com/ScoopInstaller/Scoop/issues/3479))
- **checkhashes:** Do not call scoop directly ([#3527](https://github.com/ScoopInstaller/Scoop/issues/3527))
- **config:** Show correct output when removing a config value ([#3462](https://github.com/ScoopInstaller/Scoop/issues/3462))
- **decompress:** Change dark.exe parameter order ([6141e46d](https://github.com/ScoopInstaller/Scoop/commit/6141e46d6ae74b3ccf65e02a1c3fc92e1b4d3e7a))
- **proxy:** Rename parameters for Net.NetworkCredential ([#3483](https://github.com/ScoopInstaller/Scoop/issues/3483))

### Code Refactoring

- **core:**  `run()` -> 'Invoke-ExternalCommand()' ([#3432](https://github.com/ScoopInstaller/Scoop/issues/3432))

### Documentation

- **readme:** Add known buckets to end of readme ([2849e0f9](https://github.com/ScoopInstaller/Scoop/commit/2849e0f96099004f761d7d8c715377e0d2c105f2))
- **readme:** Adjust URL of `runat.json` ([#3484](https://github.com/ScoopInstaller/Scoop/issues/3484))
- **readme:** Fix a small typo ([#3512](https://github.com/ScoopInstaller/Scoop/issues/3512))
- **readme:** Fix typo in readme ([03bb07c8](https://github.com/ScoopInstaller/Scoop/commit/03bb07c8231563fa3a2092b9b52d4dde372f2a8e))
- **readme:** Update readme with correct count of nirsoft apps ([e8d0be66](https://github.com/ScoopInstaller/Scoop/commit/e8d0be663b3bab25d9ee55c597b90bf922f4ec5d))

<a name="2019-05-15"></a>
## [2019-05-15]

### Features

- **manifest:** XPath support in checkver and autoupdate ([#3458](https://github.com/ScoopInstaller/Scoop/issues/3458))
- **update:** Support changing scoop tracking repository ([#3459](https://github.com/ScoopInstaller/Scoop/issues/3459))

### Bug Fixes

- **autoupdate:** Handle xml namespace in xpath mode ([#3465](https://github.com/ScoopInstaller/Scoop/issues/3465))

<a name="2019-05-12"></a>
## [2019-05-12]

### BREAKING CHANGE

- **core:** Finalize bucket extraction ([#3399](https://github.com/ScoopInstaller/Scoop/issues/3399))
- **core:** Bucket extraction and refactoring ([#3449](https://github.com/ScoopInstaller/Scoop/issues/3449))

### Features

- **autoupdate:** Add 'regex' alias for 'find' ([3453487e](https://github.com/ScoopInstaller/Scoop/commit/3453487ed65378cc9ba2efc658ed6bc1431ef463))
- **autoupdate:** Autoupdate improvements ([#1371](https://github.com/ScoopInstaller/Scoop/issues/1371))
- **autoupdate:** Convert base64 encoded hash values ([04c9ddeb](https://github.com/ScoopInstaller/Scoop/commit/04c9ddeb6d3b99496c39543ad468d34f4f1adeff))
- **autoupdate:** Improve base64 hash detection ([310096e2](https://github.com/ScoopInstaller/Scoop/commit/310096e2386ff3bf9082d547b140a98b92b87a83))
- **checkver:** Add 'useragent' property ([8feb3867](https://github.com/ScoopInstaller/Scoop/commit/8feb3867a74ea0340585e3e695934d96cf483a05))
- **checkver:** Add 'jsonpath' alias for 'jp' ([76fdb6b7](https://github.com/ScoopInstaller/Scoop/commit/76fdb6b74c1772bf607d2dad5f6c50269369ff88))
- **checkver:** Add 're' alias 'regex' ([468649c8](https://github.com/ScoopInstaller/Scoop/commit/468649c88dea9c1ff9614f2cdf29a521d572664e))
- **checkver:** Allow using the current version in checkver URL ([607ac9ca](https://github.com/ScoopInstaller/Scoop/commit/607ac9ca7c185da61e2c746ea87d28c2abe62adc))
- **core:** Add Expand-DarkArchive and some other dependency features ([#3450](https://github.com/ScoopInstaller/Scoop/issues/3450))
- **core:** Make shim support PowerShell 2.0 ([#2562](https://github.com/ScoopInstaller/Scoop/issues/2562))
- **core:** Prepare extraction of main bucket ([#3060](https://github.com/ScoopInstaller/Scoop/issues/3060))
- **core:** Support loading basedirs from config ([#3121](https://github.com/ScoopInstaller/Scoop/issues/3121))
- **core:** Update requirement to version 5 or greater ([#3330](https://github.com/ScoopInstaller/Scoop/issues/3330))
- **decompress:** Allow other args to be passthrough ([#3411](https://github.com/ScoopInstaller/Scoop/issues/3411))
- **shim:** Add '.com'-type shim ([#3366](https://github.com/ScoopInstaller/Scoop/issues/3366))
- **shorcuts:** Get start menu folder location from environment rather than predefined user profile path ([c245a7fe](https://github.com/ScoopInstaller/Scoop/commit/c245a7fe96ffa0b0fba23bd47f31480ea93cc183))
- **supporting:** Update Newtonsoft.Json to 11.0.2, Newtonsoft.Json.Schema to 3.0.10 ([#3043](https://github.com/ScoopInstaller/Scoop/issues/3043))
- **uninstall:** Print purge step to console ([#3123](https://github.com/ScoopInstaller/Scoop/issues/3123))
- **uninstall:** Add support for soft/purge uninstalling of scoop itself ([#2781](https://github.com/ScoopInstaller/Scoop/issues/2781))
- **update:** Add hold/unhold command ([#3444](https://github.com/ScoopInstaller/Scoop/issues/3444))
- **validator:** Improve error reporting, add support for multiple files ([#3134](https://github.com/ScoopInstaller/Scoop/issues/3134))
- **scoop-checkup:** Check for LongPaths setting ([#3387](https://github.com/ScoopInstaller/Scoop/issues/3387))
- **scoop-info:** Support url manifest ([#2538](https://github.com/ScoopInstaller/Scoop/issues/2538))
- **scoop-update:** Add notification for new main bucket ([#3392](https://github.com/ScoopInstaller/Scoop/issues/3392))

### Bug Fixes

- **autoupdate:** Fix base64 hash extraction ([98afb999](https://github.com/ScoopInstaller/Scoop/commit/98afb99990561c4f98f1e1334f348e52b4bee4e7))
- **autoupdate:** Fix metalink hash extraction ([2ad54747](https://github.com/ScoopInstaller/Scoop/commit/2ad547477b1432e7a269c90b393d62d88dce9803))
- **autoupdate:** Linter fix ([c9539b65](https://github.com/ScoopInstaller/Scoop/commit/c9539b6575e8842a8f895d82b4119c3aef01d7c2))
- **bucket:** Change wording of new_issue_msg() ([e82587df](https://github.com/ScoopInstaller/Scoop/commit/e82587dfc41618474e03347df333e847dfaffc70))
- **bucket:** Fix new_issue_msg ([#3375](https://github.com/ScoopInstaller/Scoop/issues/3375))
- **bucket:** Use $_.Name on gci result ([1eb2609d](https://github.com/ScoopInstaller/Scoop/commit/1eb2609db51587772a4b5d1b6f58114f52639568))
- **checkver:** Fix example parameters ([#3413](https://github.com/ScoopInstaller/Scoop/issues/3413))
- **checkver:** Remove old commented code ([72754036](https://github.com/ScoopInstaller/Scoop/commit/72754036a251fffd2f2eb0e242edfd9895543e3c))
- **checkver:** Resolve issue on Powershell >6.1.0 ([#2592](https://github.com/ScoopInstaller/Scoop/issues/2592))
- **core:** Filter null or empty string from Scoops directory settings ([5d5c7fa9](https://github.com/ScoopInstaller/Scoop/commit/5d5c7fa91c03f05b705d3420618ec96d8e870174))
- **core:** Fix bug with Start-Process -Wait, exclusive to PowerShell Core on Windows 7 ([#3415](https://github.com/ScoopInstaller/Scoop/issues/3415))
- **core:** Fix for relative paths ([ff9c0c3d](https://github.com/ScoopInstaller/Scoop/commit/ff9c0c3dafb3567ee958379b83205da84a925ecf))
- **core:** Format hashes to lowercase ([5d56f8ff](https://github.com/ScoopInstaller/Scoop/commit/5d56f8ff5760ddedaf44eaf9652000e833b0944e))
- **core:** Return true for checking if a directory is 'in' itself ([ac8a1567](https://github.com/ScoopInstaller/Scoop/commit/ac8a156796cb6d3d9cba24a2839271d924ab8fea))
- **decompress:** Compatible Expand-ZipArchive() with Pscx ([#3425](https://github.com/ScoopInstaller/Scoop/issues/3425))
- **decompress:** Correct deprecation function name ([#3406](https://github.com/ScoopInstaller/Scoop/issues/3406))
- **decompress:** Fix dark parameter order ([87a1e784](https://github.com/ScoopInstaller/Scoop/commit/87a1e784d7463fea36fa41fcb7cb5537cbcfdc52))
- **depends:** Don't force adding dark dependency ([#3453](https://github.com/ScoopInstaller/Scoop/issues/3453))
- **depends:** Don't include the requested app in the list of dependencies ([1bc6a479](https://github.com/ScoopInstaller/Scoop/commit/1bc6a479ee969e44e2b0d83ed6ff19efd86c6ae9))
- **download:** Fix fosshub downloads with aria2c ([803525a8](https://github.com/ScoopInstaller/Scoop/commit/803525a8661ffaa39fc4ad6f0dc776cccad4c45e))
- **download:** Interrupt download causes partial cache file to be used for next install ([5be02865](https://github.com/ScoopInstaller/Scoop/commit/5be0286561398debfee2c0610e51f006ef2dc2fb))
- **download:** Overwrite any existing files when extracting ([58cca68f](https://github.com/ScoopInstaller/Scoop/commit/58cca68f7565bd5e8f63e08ad052c0029b98a23d))
- **getopt:** Don't try to parse int arguments ([23fe5a53](https://github.com/ScoopInstaller/Scoop/commit/23fe5a5319d4ede84c532df04f576c3854fd5826))
- **getopt:** Don't try to parse array arguments ([9b6e7b5e](https://github.com/ScoopInstaller/Scoop/commit/9b6e7b5e0f7f6ddecdb139f932ad7d582fe639a4))
- **getopt:** Return remaining args, use getopt for scoop install ([b7cfd6fd](https://github.com/ScoopInstaller/Scoop/commit/b7cfd6fdb0e18a623ceacfa6fc824241dabc6d01))
- **getopt:** Skip if arg is $null ([f2d9f0d7](https://github.com/ScoopInstaller/Scoop/commit/f2d9f0d79fdf4a63879c1b87a6c0f5317a40a1d9))
- **getopt:** Skip arg if it's decimal ([5f0c8cfb](https://github.com/ScoopInstaller/Scoop/commit/5f0c8cfb0a34078bb8118a21191cf046ddad18ac))
- **json:** Catch JsonReaderException ([fb58e92c](https://github.com/ScoopInstaller/Scoop/commit/fb58e92c13552199f19f5df112801fc41321eee2))
- **install:** Ignore url fragment for PowerShell Core 6.1.0 ([#2602](https://github.com/ScoopInstaller/Scoop/issues/2602))
- **persist:** Fix the target didn't be created ([#3008](https://github.com/ScoopInstaller/Scoop/issues/3008))
- **scoop:** Force to add new main bucket ([#3419](https://github.com/ScoopInstaller/Scoop/issues/3419))
- **schema:** extract_to property is on active duty (not deprecated) ([59e994c5](https://github.com/ScoopInstaller/Scoop/commit/59e994c5fdeb8dffe6037ca6767d56ad13bf04da))
- **uninstall:** Uninstall fails to remove architecture-specific shims ([8b1871b2](https://github.com/ScoopInstaller/Scoop/commit/8b1871b20df4dbf1b603d4066937ba213c03bb32))
- **update:** Rewording PowerShell update notice ([d006fb93](https://github.com/ScoopInstaller/Scoop/commit/d006fb9315b55a9d8e6a36218cf5dbdde51433ec))
- **scoop-cache:** Display help on incorrect cache command ([#3431](https://github.com/ScoopInstaller/Scoop/issues/3431))
- **scoop-cache:** scoop cache command not using $SCOOP_CACHE ([#1990](https://github.com/ScoopInstaller/Scoop/issues/1990))
- **scoop-reset:** Re-create shortcuts ([6e5b7e57](https://github.com/ScoopInstaller/Scoop/commit/6e5b7e57bb0628f072872d9a5b8c8a0fa58389e1))
- **scoop-search:** Better handling for invalid query ([bf024705](https://github.com/ScoopInstaller/Scoop/commit/bf024705a8cc38592571aa3026dca2471f19ac5a))
- **scoop-update:** First scoop update fails because scoop deletes itself too early ([376630fd](https://github.com/ScoopInstaller/Scoop/commit/376630fd80a3f9012fd6e673460b9e28e375e951))
- **scoop-update:** Fix branch switching ([#3372](https://github.com/ScoopInstaller/Scoop/issues/3372))

### Code Refactoring

- **bucket:** Move function into lib from lib-exec ([#3062](https://github.com/ScoopInstaller/Scoop/issues/3062))
- **config:** Move configuration handling to core.ps1 ([#3242](https://github.com/ScoopInstaller/Scoop/issues/3242))
- **core:** cmd_available() -> Test-CommandAvailable() ([#3314](https://github.com/ScoopInstaller/Scoop/issues/3314))
- **core:** ensure_all_installed() -> Confirm-InstallationStatus() ([#3293](https://github.com/ScoopInstaller/Scoop/issues/3293))
- **core:** Move default_aliases into the scoped function ([#3233](https://github.com/ScoopInstaller/Scoop/issues/3233))
- **core:** Refactor function names and fix installing 7zip locally if already globally available ([#3416](https://github.com/ScoopInstaller/Scoop/issues/3416))
- **core:** Tweak SecurityProtocol usage ([#3065](https://github.com/ScoopInstaller/Scoop/issues/3065))
- **decompress:** Refactored (w/ install.ps1, core.ps1) ([#3169](https://github.com/ScoopInstaller/Scoop/issues/3169))
- **decompress:** Refactor extraction handling functions ([#3204](https://github.com/ScoopInstaller/Scoop/issues/3204))
- **download:** Download functionality refactor ([#1329](https://github.com/ScoopInstaller/Scoop/issues/1329))
- **install:** Rename locate() to Find-Manifest() ([9eed3d89](https://github.com/ScoopInstaller/Scoop/commit/9eed3d8914c7a0fa294110eb0761776a01adf034))

### Continuous Integration

- **appveyor:** Rebuild cache ([7311b41b](https://github.com/ScoopInstaller/Scoop/commit/7311b41b8d1e2e010175fb7d079662bbcba5bac8))
- **appveyor:** Run tests for PowerShell 5 and 6 ([#2603](https://github.com/ScoopInstaller/Scoop/issues/2603))
- **test:** Add -TestPath param to test.ps1 ([f857dce9](https://github.com/ScoopInstaller/Scoop/commit/f857dce9f59a490f6dd07085c3abaa51e9577fda))
- **test:** Force install PSScriptAnalyzer and BuildHelpers ([7a1b5a18](https://github.com/ScoopInstaller/Scoop/commit/7a1b5a1840e30321951fa0f5333c34d10f57fa94))
- **test:** Require BuildHelpers version 2.0.0 ([ac3ee766](https://github.com/ScoopInstaller/Scoop/commit/ac3ee766722e99c1f15dc60a1f1dfb0a48428c55))
- **test:** Improve installation of lessmsi and innounp ([#3409](https://github.com/ScoopInstaller/Scoop/issues/3409))
- **test:** Update BuildHelpers to version 2.0.1 ([dde4d0f9](https://github.com/ScoopInstaller/Scoop/commit/dde4d0f93f260191af5524c0ecab927f3e252361))

### Styles

- **lint:** PSAvoidUsingCmdletAliases ([#2075](https://github.com/ScoopInstaller/Scoop/issues/2075))

### Tests

- **bucket:** Add importable tests for Buckets ([478f52c4](https://github.com/ScoopInstaller/Scoop/commit/478f52c421ca35ea35b5fd0b2df2631cf7d82487))
- **bucket:** Fix manifest tests for buckets ([589303fa](https://github.com/ScoopInstaller/Scoop/commit/589303facc5284f6f95c1305191e0558c0169691))
- **bucket:** Handle JSON.NET schema validation limit exceeded. ([139813a8](https://github.com/ScoopInstaller/Scoop/commit/139813a8f50ace85e2752d9b6c9f82fc64ff3e48))
- **file:** Move style constraints tests to separate test file ([7b7113fc](https://github.com/ScoopInstaller/Scoop/commit/7b7113fc3bf962aaeba625f58341c30a80f0fe6a))

### Documentation

- **readme:** Add discord chat badge ([#3241](https://github.com/ScoopInstaller/Scoop/issues/3241))
- **readme:** Update Discord invite link ([5f269249](https://github.com/ScoopInstaller/Scoop/commit/5f269249609b43f5c4fa9aba4def999e7ee05fe1))
- **readme:** Fix typo (you -> your), (it's -> its) ([#2698](https://github.com/ScoopInstaller/Scoop/issues/2698))
- **readme:** Remove trailing whitespaces ([d25186bf](https://github.com/ScoopInstaller/Scoop/commit/d25186bf1f833e30d8c5b530b7c260fe399b75ed))
- **readme:** Remove "tail" from example (is coreutils) ([#2158](https://github.com/ScoopInstaller/Scoop/issues/2158))
