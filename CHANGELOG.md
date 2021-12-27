<a name="unreleased"></a>
## [Unreleased]

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
- **depends:** Prevent error on no URL ([#4595](https://github.com/ScoopInstaller/Scoop/issues/4595))
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

### Documents

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

### Documents

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
- **checkup:** Add check_envs_requirements ([ad9f7c6f](https://github.com/ScoopInstaller/Scoop/commit/ad9f7c6ff1827ea0bc7479877f8564e0130c53d8))
- **checkver:** Present script property ([#3900](https://github.com/ScoopInstaller/Scoop/issues/3900))
- **config:** Add configuration option for default architecture ([#3778](https://github.com/ScoopInstaller/Scoop/issues/3778))
- **diagnostic:** Add check_envs_requirements ([062e6d79](https://github.com/ScoopInstaller/Scoop/commit/062e6d797396c6015f5a293b6ee6c2447760366d))
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

### CI/CD

- **appveyor:** use VS2019 image to fix PS6 issues ([#3646](https://github.com/ScoopInstaller/Scoop/issues/3646))

### Documents

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

### Documents

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
## 2019-05-12

### Apps_in_bucket

- Use $_.Name on gci result (closes [#2707](https://github.com/ScoopInstaller/Scoop/issues/2707))

### Appveyor

- Remove trailing comma from params ([53e73f52](https://github.com/ScoopInstaller/Scoop/commit/53e73f5211215b6d6735878c5f3798204c89f0f3))
- Add -TestPath param to test.ps1 ([f857dce9](https://github.com/ScoopInstaller/Scoop/commit/f857dce9f59a490f6dd07085c3abaa51e9577fda))
- Force install PSScriptAnalyzer and BuildHelpers ([7a1b5a18](https://github.com/ScoopInstaller/Scoop/commit/7a1b5a1840e30321951fa0f5333c34d10f57fa94))
- Update BuildHelpers to version 2.0.1 ([dde4d0f9](https://github.com/ScoopInstaller/Scoop/commit/dde4d0f93f260191af5524c0ecab927f3e252361))
- rebuild cache ([7311b41b](https://github.com/ScoopInstaller/Scoop/commit/7311b41b8d1e2e010175fb7d079662bbcba5bac8))
- require BuildHelpers version 2.0.0 ([ac3ee766](https://github.com/ScoopInstaller/Scoop/commit/ac3ee766722e99c1f15dc60a1f1dfb0a48428c55))
- rebuild cache ([d3e1bdd6](https://github.com/ScoopInstaller/Scoop/commit/d3e1bdd6ff7e1d47bdf64fb44eb7f187fa2f9093))
- Run tests for PowerShell 5 and 6 ([#2603](https://github.com/ScoopInstaller/Scoop/issues/2603))

### Autoupdate

- improve base64 hash detection ([310096e2](https://github.com/ScoopInstaller/Scoop/commit/310096e2386ff3bf9082d547b140a98b92b87a83))
- add 'regex' alias for 'find' ([3453487e](https://github.com/ScoopInstaller/Scoop/commit/3453487ed65378cc9ba2efc658ed6bc1431ef463))
- Fix base64 hash extraction ([98afb999](https://github.com/ScoopInstaller/Scoop/commit/98afb99990561c4f98f1e1334f348e52b4bee4e7))
- linter fix ([c9539b65](https://github.com/ScoopInstaller/Scoop/commit/c9539b6575e8842a8f895d82b4119c3aef01d7c2))
- Convert base64 encoded hash values ([04c9ddeb](https://github.com/ScoopInstaller/Scoop/commit/04c9ddeb6d3b99496c39543ad468d34f4f1adeff))
- Fix metalink hash extraction ([2ad54747](https://github.com/ScoopInstaller/Scoop/commit/2ad547477b1432e7a269c90b393d62d88dce9803))
- do not autodowngrade ([df74d2bc](https://github.com/ScoopInstaller/Scoop/commit/df74d2bc0e21883eb8a8dc4c237684d4c48937ec))

### Bucket

- PHP: 64bit download added. ([3a9eb856](https://github.com/ScoopInstaller/Scoop/commit/3a9eb856c8005e8879023acf92ddd2f6385c503b))

### Buckets

- Move function into lib from lib-exec ([#3062](https://github.com/ScoopInstaller/Scoop/issues/3062))
- change wording of new_issue_msg() ([e82587df](https://github.com/ScoopInstaller/Scoop/commit/e82587dfc41618474e03347df333e847dfaffc70))

### Bug Fixes

- force to add new main bucket ([#3419](https://github.com/ScoopInstaller/Scoop/issues/3419))
- overwrite any existing files when extracting ([58cca68f](https://github.com/ScoopInstaller/Scoop/commit/58cca68f7565bd5e8f63e08ad052c0029b98a23d))
- uninstall fails to remove architecture-specific shims (fixes [#1191](https://github.com/ScoopInstaller/Scoop/issues/1191))
- interrupt download causes partial cache file to be used for next install ([5be02865](https://github.com/ScoopInstaller/Scoop/commit/5be0286561398debfee2c0610e51f006ef2dc2fb))
- correct deprecation function name ([#3406](https://github.com/ScoopInstaller/Scoop/issues/3406))
- **checkup:** Remove lessmsi and aria2 from scoop checkup command ([84631197](https://github.com/ScoopInstaller/Scoop/commit/846311970f5683d271936696db0f72454588ce78))
- **config:** More tests for set_config ([630ba04e](https://github.com/ScoopInstaller/Scoop/commit/630ba04ecd81d85d882b623af20a8b836821a141))
- **config:** Test for DateTime object instead for actual Time ([d17b4e5a](https://github.com/ScoopInstaller/Scoop/commit/d17b4e5a8570b05d3399b66a7a4ba73e076c54d5))
- **config:** fix datetime tests for PowerShell 6 ([8dd68f61](https://github.com/ScoopInstaller/Scoop/commit/8dd68f61b0186bced792335ce063d49a5d6ec03f))
- **config:** fix set_config check for existing property ([c9fa59da](https://github.com/ScoopInstaller/Scoop/commit/c9fa59dab80f51da52150b8300d69118445e9b61))
- **config:** Remove config.ps1 imports ([7699beaf](https://github.com/ScoopInstaller/Scoop/commit/7699beafc04d74d2e34b05dfdeb3cf1a30dbb6af))
- **core:** Filter null or empty string from Scoops directory settings ([5d5c7fa9](https://github.com/ScoopInstaller/Scoop/commit/5d5c7fa91c03f05b705d3420618ec96d8e870174))
- **core:** Remove wrong parenthesis Test-Aria2Enabled and Get-AppFilePath ([83e45766](https://github.com/ScoopInstaller/Scoop/commit/83e457661da3fdc43a0a21e9f5a17fdbc3a26404))
- **decompress:** Fix return value of extract_7zip ([d3ba0b20](https://github.com/ScoopInstaller/Scoop/commit/d3ba0b203f84977bac362e42ec3f42f02add8c7c))
- **decompress:** Fix dark parameter order ([87a1e784](https://github.com/ScoopInstaller/Scoop/commit/87a1e784d7463fea36fa41fcb7cb5537cbcfdc52))
- **depends:** don't force adding dark dependency ([#3453](https://github.com/ScoopInstaller/Scoop/issues/3453))
- **install:** Check if 7zip/lessmsi/innounp is installed before adding dependency ([51c6e77d](https://github.com/ScoopInstaller/Scoop/commit/51c6e77d612a1df2bedd8ec5aa8c2128430ebad1))
- **persist:** fix the target didn't be created ([#3008](https://github.com/ScoopInstaller/Scoop/issues/3008))
- **scoop-update:** fix branch switching ([#3372](https://github.com/ScoopInstaller/Scoop/issues/3372)) ([404a6b82](https://github.com/ScoopInstaller/Scoop/commit/404a6b82a626317f1338b16596f17f0485eeaf08))
- **scoop-update:** fix branch switching ([#3372](https://github.com/ScoopInstaller/Scoop/issues/3372))
- **update:** Rewording PowerShell update notice ([d006fb93](https://github.com/ScoopInstaller/Scoop/commit/d006fb9315b55a9d8e6a36218cf5dbdde51433ec))

### Checkver

- add 'useragent' property ([8feb3867](https://github.com/ScoopInstaller/Scoop/commit/8feb3867a74ea0340585e3e695934d96cf483a05))
- remove old commented code ([72754036](https://github.com/ScoopInstaller/Scoop/commit/72754036a251fffd2f2eb0e242edfd9895543e3c))
- add 'jsonpath' alias for 'jp' ([76fdb6b7](https://github.com/ScoopInstaller/Scoop/commit/76fdb6b74c1772bf607d2dad5f6c50269369ff88))
- Add 're' alias 'regex' ([468649c8](https://github.com/ScoopInstaller/Scoop/commit/468649c88dea9c1ff9614f2cdf29a521d572664e))
- Resolve issue on Powershell >6.1.0 ([#2592](https://github.com/ScoopInstaller/Scoop/issues/2592))
- Allow using the current version in checkver URL ([607ac9ca](https://github.com/ScoopInstaller/Scoop/commit/607ac9ca7c185da61e2c746ea87d28c2abe62adc))

### Chores

- add notification for new main bucket ([#3392](https://github.com/ScoopInstaller/Scoop/issues/3392))

### Code Refactoring

- move core bootstrapper to the eof ([ee7d22a5](https://github.com/ScoopInstaller/Scoop/commit/ee7d22a52dc5d55fd9af8eba428d1d275f8d1f0e))
- **alias:** Apply config changes to scoop-alias command ([8ead07ff](https://github.com/ScoopInstaller/Scoop/commit/8ead07ffee07901fbac974625ece26f9b8dfcc2f))
- **config:** Redirect set_config output to Out-Null ([fcabada1](https://github.com/ScoopInstaller/Scoop/commit/fcabada1bc73f65c102d282411617ca0c8f8e5c2))
- **config:** Better output for scoop config command ([9f4bc2a7](https://github.com/ScoopInstaller/Scoop/commit/9f4bc2a77fc74ac483ccc3d484a81a909ad031a0))
- **config:** Fix warning message ([7e40e2e6](https://github.com/ScoopInstaller/Scoop/commit/7e40e2e61c4f7fd28d10704ae517268854c35915))
- **config:** Fix set_config ([1e198293](https://github.com/ScoopInstaller/Scoop/commit/1e198293343961af19d47bf024db80a80d402f24))
- **config:** Add more tests for load_config and get_config ([40d83d92](https://github.com/ScoopInstaller/Scoop/commit/40d83d924a084f15edc137aebfe7efce76a2b38d))
- **config:** Fix set_config function ([1e1a8067](https://github.com/ScoopInstaller/Scoop/commit/1e1a806783f95b6b16eaf213d6a93662f3077ccd))
- **config:** Move configuration handling to core.ps1 ([f7a9cd9c](https://github.com/ScoopInstaller/Scoop/commit/f7a9cd9ceb5e6736c2f0058a5a8c5b58279b8980))
- **config:** Fix config value removing ([df64db06](https://github.com/ScoopInstaller/Scoop/commit/df64db0675d2b8ab578af146c14bfd34ddf35387))
- **core:** remove old scoopdir support ([89558f41](https://github.com/ScoopInstaller/Scoop/commit/89558f41fd5fe9c5a2626872ef1b1748fe2cdd3a))
- **core:** Prefer $XDG_CONFIG_HOME over ~\.config ([2749104e](https://github.com/ScoopInstaller/Scoop/commit/2749104e82940fd12f9b2c7b07f5e94fd6ae6017))
- **core:** Use ASCII encoding because of PowerShell 5 ([f1c4a6cc](https://github.com/ScoopInstaller/Scoop/commit/f1c4a6cc64f9b598d4b58712a212a32bb8560685))
- **core:** ensure config path exists ([e9004e12](https://github.com/ScoopInstaller/Scoop/commit/e9004e126b040279f07538c0ec31208fd4a1eeed))
- **core:** Remove hard-coded path ([445d4fde](https://github.com/ScoopInstaller/Scoop/commit/445d4fdee2847bb98c2ad0c428899f8da72de792))
- **core:** ensure_all_installed() to Confirm-InstallationStatus() ([#3293](https://github.com/ScoopInstaller/Scoop/issues/3293))
- **core:** Combine helpers to Get-HelperPath and Test-HelperInstalled ([010546cf](https://github.com/ScoopInstaller/Scoop/commit/010546cf26680668917c732810d936651f00ead8))
- **core:** file_path > Get-AppFilePath ([3cb37f0c](https://github.com/ScoopInstaller/Scoop/commit/3cb37f0cd1a03d111720afcd699aca8f46774383))
- **core:** Rename aria2 helper functions ([42e45050](https://github.com/ScoopInstaller/Scoop/commit/42e450508995224887838cd4f73cfad9df9ea520))
- **core:** move default_aliases into the scoped function ([#3233](https://github.com/ScoopInstaller/Scoop/issues/3233))
- **decompress:** Change function name casing ([501d4b4d](https://github.com/ScoopInstaller/Scoop/commit/501d4b4d353a55d12aea028d6d78cd105940156a))
- **decompress:** Use helper functions for 7zip/lessmsi/innounp ([e1622558](https://github.com/ScoopInstaller/Scoop/commit/e16225582402d015e336fd844a7db74f026f0fc2))
- **install:** rename locate() to Find-Manifest() ([9eed3d89](https://github.com/ScoopInstaller/Scoop/commit/9eed3d8914c7a0fa294110eb0761776a01adf034))
- **tests:** Check checksum of TestCases.zip before extracting ([f58fdaa7](https://github.com/ScoopInstaller/Scoop/commit/f58fdaa7f206eae21bef4c067e475be5c46120cc))

### Core

- Make shim support PowerShell 2.0 ([#2562](https://github.com/ScoopInstaller/Scoop/issues/2562))

### Decompress

- Fix get_config calls ([79a6d5cb](https://github.com/ScoopInstaller/Scoop/commit/79a6d5cb04c11c191a8c26e3e7f061b1da2c80ac))
- **tests:** Improve installation of lessmsi and innounp ([#3409](https://github.com/ScoopInstaller/Scoop/issues/3409))
- **tests:** Use BeforeAll to setup variables and install dependencies ([ff15d1d6](https://github.com/ScoopInstaller/Scoop/commit/ff15d1d69f9819512bbc07474bc45801994a8b91))
- **tests:** Skip already installed app ([f919a3c7](https://github.com/ScoopInstaller/Scoop/commit/f919a3c7c17e370e8e88cafd03a1fa5d2e205600))

### Depends

- don't include the requested app in the list of dependencies ([1bc6a479](https://github.com/ScoopInstaller/Scoop/commit/1bc6a479ee969e44e2b0d83ed6ff19efd86c6ae9))

### Documents

- **readme:** add discord chat badge ([#3241](https://github.com/ScoopInstaller/Scoop/issues/3241))

### Editorconfig

- Fix checkver ([#3231](https://github.com/ScoopInstaller/Scoop/issues/3231))
- Update to version 0.12.3 ([8bfd90e3](https://github.com/ScoopInstaller/Scoop/commit/8bfd90e3babc195eff665db255550b46312ae85b))
- revert to version 0.12.1 (closes [#2250](https://github.com/ScoopInstaller/Scoop/issues/2250))

### Feature

- Prepare extraction of main bucket ([#3060](https://github.com/ScoopInstaller/Scoop/issues/3060))
- **checkup:** Add warnings to 'scoop checkup' for missing unpackers ([f578cd07](https://github.com/ScoopInstaller/Scoop/commit/f578cd0767d95cdfa1a3f109ecfc270374add53b))
- **core:** Allow wixtoolset and 7zip-zstd as valid helpers ([039d591b](https://github.com/ScoopInstaller/Scoop/commit/039d591b1ab3439bb306739b064c36e9539f9a2a))
- **core:** Add lessmsi and innounp helper functions ([1149402f](https://github.com/ScoopInstaller/Scoop/commit/1149402f29b084e3686a8ab12a17a2346d97c3fd))
- **decompress:** Add Expand-DarkArchive helper function ([27afed09](https://github.com/ScoopInstaller/Scoop/commit/27afed09d4c2943ea43666f0a3a466c6e1942c57))
- **depends:** Detect dependencies from pre/post and installer script ([2aec0b2d](https://github.com/ScoopInstaller/Scoop/commit/2aec0b2d97d6f877511c5db7f25582a39860a79b))
- **scoop-info:** support url manifest ([#2538](https://github.com/ScoopInstaller/Scoop/issues/2538))
- **update:** Add hold/unhold command ([#3444](https://github.com/ScoopInstaller/Scoop/issues/3444))

### Features

- support loading basedirs from config ([f53ffc6c](https://github.com/ScoopInstaller/Scoop/commit/f53ffc6c5829dd0c276ad3f205a998d38933643f))
- Check for LongPaths setting ([#3387](https://github.com/ScoopInstaller/Scoop/issues/3387))
- **yarn:** set and persist offline mirror ([#2037](https://github.com/ScoopInstaller/Scoop/issues/2037))

### Fix

- scoop cache command not using $SCOOP_CACHE ([#1990](https://github.com/ScoopInstaller/Scoop/issues/1990))
- Progress bar no longer jumps when hitting 100% ([f62dacef](https://github.com/ScoopInstaller/Scoop/commit/f62dacef0b87d742500ccb762ccb0cf59019fd4e))
- Haxe 3.4.0-rc.2 bucket error moving dir ([807b30f3](https://github.com/ScoopInstaller/Scoop/commit/807b30f33cd9d8c1678d4f8daece4ae02231a8e2))
- first scoop update fails because scoop deletes itself too early (needs to call itself to get proxy config for git clone) ([376630fd](https://github.com/ScoopInstaller/Scoop/commit/376630fd80a3f9012fd6e673460b9e28e375e951))

### Format_hash

- format hashes to lowercase ([5d56f8ff](https://github.com/ScoopInstaller/Scoop/commit/5d56f8ff5760ddedaf44eaf9652000e833b0944e))

### Getopt

- skip if arg is $null ([f2d9f0d7](https://github.com/ScoopInstaller/Scoop/commit/f2d9f0d79fdf4a63879c1b87a6c0f5317a40a1d9))
- skip arg if it's decimal (closes [#2598](https://github.com/ScoopInstaller/Scoop/issues/2598))
- don't try to parse int arguments ([23fe5a53](https://github.com/ScoopInstaller/Scoop/commit/23fe5a5319d4ede84c532df04f576c3854fd5826))
- don't try to parse array arguments ([9b6e7b5e](https://github.com/ScoopInstaller/Scoop/commit/9b6e7b5e0f7f6ddecdb139f932ad7d582fe639a4))
- return remaining args, use getopt for scoop install ([b7cfd6fd](https://github.com/ScoopInstaller/Scoop/commit/b7cfd6fdb0e18a623ceacfa6fc824241dabc6d01))

### Install

- Fix bug with Start-Process -Wait, exclusive to PowerShell Core on Windows 7 ([#3415](https://github.com/ScoopInstaller/Scoop/issues/3415))
- fix fosshub downloads with aria2c ([803525a8](https://github.com/ScoopInstaller/Scoop/commit/803525a8661ffaa39fc4ad6f0dc776cccad4c45e))
- ignore url fragment for PowerShell Core 6.1.0 ([#2602](https://github.com/ScoopInstaller/Scoop/issues/2602))
- auto-install dependencies ([4f2cd4bb](https://github.com/ScoopInstaller/Scoop/commit/4f2cd4bbf620d666c13a8e4d2325939431caa163))

### Is_in_dir

- return true for checking if a directory is 'in' itself ([ac8a1567](https://github.com/ScoopInstaller/Scoop/commit/ac8a156796cb6d3d9cba24a2839271d924ab8fea))

### Json

- catch JsonReaderException ([fb58e92c](https://github.com/ScoopInstaller/Scoop/commit/fb58e92c13552199f19f5df112801fc41321eee2))

### Lint

- PSAvoidUsingCmdletAliases ([#2075](https://github.com/ScoopInstaller/Scoop/issues/2075))

### Parse_app

- fix for relative paths ([ff9c0c3d](https://github.com/ScoopInstaller/Scoop/commit/ff9c0c3dafb3567ee958379b83205da84a925ecf))

### Patch

- **decompress:** Allow other args to be passthrough ([#3411](https://github.com/ScoopInstaller/Scoop/issues/3411))

### Persistence

- prevent NPM from overwriting node_modules by setting read-only attribute on the persisted directory junction. ([732cf2ca](https://github.com/ScoopInstaller/Scoop/commit/732cf2caa2a9a0eff1005fa1723a0dc22e3e02f1))

### PowerShell

- Update requirement to version 5 or greater ([#3330](https://github.com/ScoopInstaller/Scoop/issues/3330))

### README

- remove trailing whitespaces ([d25186bf](https://github.com/ScoopInstaller/Scoop/commit/d25186bf1f833e30d8c5b530b7c260fe399b75ed))
- Fix typo (you -> your), (it's -> its) ([#2698](https://github.com/ScoopInstaller/Scoop/issues/2698))
- Remove "tail" from example (is coreutils) ([#2158](https://github.com/ScoopInstaller/Scoop/issues/2158))

### Readme

- Update Discord invite link ([5f269249](https://github.com/ScoopInstaller/Scoop/commit/5f269249609b43f5c4fa9aba4def999e7ee05fe1))

### Red

- fix hash (fixes [#2817](https://github.com/ScoopInstaller/Scoop/issues/2817))
- Update to version 0.6.4 ([cc4d5d37](https://github.com/ScoopInstaller/Scoop/commit/cc4d5d377d1a8be1c6770b23d3cda6805c204c9b))
- Update to version 0.6.3 ([52fd6fed](https://github.com/ScoopInstaller/Scoop/commit/52fd6fedc89b2db6569362e7d52f14afa69fe60c))
- Update to version 063 ([4b8e7ef3](https://github.com/ScoopInstaller/Scoop/commit/4b8e7ef3a1de6e4842704e868f7f600fd0776025))

### Refactor

- Tweak SecurityProtocol usage ([#3065](https://github.com/ScoopInstaller/Scoop/issues/3065))

### Rename

- 'scoop cache clear' to 'scoop cache rm' ([44416c99](https://github.com/ScoopInstaller/Scoop/commit/44416c99d4c2a5ca03e8fdcd3088330a8d03b620))

### Reset

- Re-create shortcuts (fixes [#1406](https://github.com/ScoopInstaller/Scoop/issues/1406))

### Schema

- extract_to property is on active duty (not deprecated) close [#3312](https://github.com/ScoopInstaller/Scoop/issues/3312) ([59e994c5](https://github.com/ScoopInstaller/Scoop/commit/59e994c5fdeb8dffe6037ca6767d56ad13bf04da))

### Search

- better handling for invalid query (fixes [#634](https://github.com/ScoopInstaller/Scoop/issues/634) ([bf024705](https://github.com/ScoopInstaller/Scoop/commit/bf024705a8cc38592571aa3026dca2471f19ac5a))

### Shim

- Add '.com'-type shim ([#3366](https://github.com/ScoopInstaller/Scoop/issues/3366))

### Shimexe

- for programs that exit quickly, make sure any remaining output on stderr or stdout is pumped to the right output stream ([da0b1097](https://github.com/ScoopInstaller/Scoop/commit/da0b109755699d30910456d8bccc21bf4b2bd10d))

### Shortcuts

- get start menu folder location from environment rather than predefined user profile path (see [#1029](https://github.com/ScoopInstaller/Scoop/issues/1029))

### Supporting

- Update Newtonsoft.Json to 11.0.2, Newtonsoft.Json.Schema to 3.0.10 ([#3043](https://github.com/ScoopInstaller/Scoop/issues/3043))

### Tests

- Fix manifest tests for buckets ([589303fa](https://github.com/ScoopInstaller/Scoop/commit/589303facc5284f6f95c1305191e0558c0169691))
- Add importable tests for Buckets ([478f52c4](https://github.com/ScoopInstaller/Scoop/commit/478f52c421ca35ea35b5fd0b2df2631cf7d82487))
- Move style constraints tests to separate test file ([7b7113fc](https://github.com/ScoopInstaller/Scoop/commit/7b7113fc3bf962aaeba625f58341c30a80f0fe6a))

### Tests

- handle JSON.NET schema validation limit exceeded. ([139813a8](https://github.com/ScoopInstaller/Scoop/commit/139813a8f50ace85e2752d9b6c9f82fc64ff3e48))

### Uncache

- handle no <app> ([f0d1d37f](https://github.com/ScoopInstaller/Scoop/commit/f0d1d37f6394b909718f560bfaecc12ee3e3860d))

### Uninstall

- Print purge step to console ([#3123](https://github.com/ScoopInstaller/Scoop/issues/3123))

### Uninstall

- Add support for soft/purge uninstalling of scoop itself ([#2781](https://github.com/ScoopInstaller/Scoop/issues/2781))
- remove scoop from path add sublime project with settings to use windows line endings by default ([ff3cd3e7](https://github.com/ScoopInstaller/Scoop/commit/ff3cd3e77b344acfbf22e27cad74b60783bbfff0))

### Unzip

- fall back to shell COM object if .NET earlier than 4.5 ([#66](https://github.com/ScoopInstaller/Scoop/issues/66))
- allow targeting a folder inside the zip ([10eb5b7c](https://github.com/ScoopInstaller/Scoop/commit/10eb5b7c5366816062afac303342f4a3e0f11431))

### Validator

- Improve error reporting, add support for multiple files ([7bedd449](https://github.com/ScoopInstaller/Scoop/commit/7bedd449b5bb4ef6d4a53a9f4aee48db3fb847bf))

### Reverts

- Update file to 5.30-1
- Update sed to 4.4-2
- Update grep to 3.0-1 ([#1618](https://github.com/ScoopInstaller/Scoop/issues/1618))
- Throttle progress bar output
- Bringing back download progress
- Restore separate app for Apache/PHP Visual C++ dependency
- Revert "Revert "Update OpenSSH to 7.1p1""
- Revert "Update OpenSSH to 7.1p1"
- Update OpenSSH to 7.1p1
- Add ability to reset scoop (also adds Git Bash support)
- Added support for custom commands
- Create strings.json
- updated for new color naming in concfg (see lukesampson/concfg[#3](https://github.com/ScoopInstaller/Scoop/issues/3)

### Pull Requests

- Merge pull request [#2996](https://github.com/ScoopInstaller/Scoop/issues/2996) from niheaven/add-version-variables-to-regex-in-hash-extract
- Merge pull request [#2751](https://github.com/ScoopInstaller/Scoop/issues/2751) from moosad/updates
- Merge pull request [#2286](https://github.com/ScoopInstaller/Scoop/issues/2286) from h404bi/patch-3
- Merge pull request [#2283](https://github.com/ScoopInstaller/Scoop/issues/2283) from tothtamas28/master
- Merge pull request [#2281](https://github.com/ScoopInstaller/Scoop/issues/2281) from gnsngck/patch-1
- Merge pull request [#2279](https://github.com/ScoopInstaller/Scoop/issues/2279) from quincunx/master
- Merge pull request [#2278](https://github.com/ScoopInstaller/Scoop/issues/2278) from jjaarrvviiss/patch-1
- Merge pull request [#2247](https://github.com/ScoopInstaller/Scoop/issues/2247) from rasa/rasa/fix2243
- Merge pull request [#2148](https://github.com/ScoopInstaller/Scoop/issues/2148) from h404bi/patch-1
- Merge pull request [#1824](https://github.com/ScoopInstaller/Scoop/issues/1824) from rasa/rasa/smartmontools
- Merge pull request [#1682](https://github.com/ScoopInstaller/Scoop/issues/1682) from matthewjberger/master
- Merge pull request [#1674](https://github.com/ScoopInstaller/Scoop/issues/1674) from lukesampson/wuzz
- Merge pull request [#1665](https://github.com/ScoopInstaller/Scoop/issues/1665) from prabirshrestha/gof
- Merge pull request [#1668](https://github.com/ScoopInstaller/Scoop/issues/1668) from rasa/patch-1
- Merge pull request [#1664](https://github.com/ScoopInstaller/Scoop/issues/1664) from matthewjberger/master
- Merge pull request [#1662](https://github.com/ScoopInstaller/Scoop/issues/1662) from matthewjberger/master
- Merge pull request [#1658](https://github.com/ScoopInstaller/Scoop/issues/1658) from matthewjberger/master
- Merge pull request [#1657](https://github.com/ScoopInstaller/Scoop/issues/1657) from lukesampson/script-un-installer
- Merge pull request [#1656](https://github.com/ScoopInstaller/Scoop/issues/1656) from matthewjberger/master
- Merge pull request [#1655](https://github.com/ScoopInstaller/Scoop/issues/1655) from matthewjberger/master
- Merge pull request [#1654](https://github.com/ScoopInstaller/Scoop/issues/1654) from inosik/git-lfs/suggest-git
- Merge pull request [#1652](https://github.com/ScoopInstaller/Scoop/issues/1652) from baev/patch-1
- Merge pull request [#1649](https://github.com/ScoopInstaller/Scoop/issues/1649) from matthewjberger/master
- Merge pull request [#1646](https://github.com/ScoopInstaller/Scoop/issues/1646) from matthewjberger/master
- Merge pull request [#1645](https://github.com/ScoopInstaller/Scoop/issues/1645) from martinlindhe/master
- Merge pull request [#1644](https://github.com/ScoopInstaller/Scoop/issues/1644) from martinlindhe/master
- Merge pull request [#1643](https://github.com/ScoopInstaller/Scoop/issues/1643) from matthewjberger/master
- Merge pull request [#1640](https://github.com/ScoopInstaller/Scoop/issues/1640) from rasa/rasa/qemu
- Merge pull request [#1639](https://github.com/ScoopInstaller/Scoop/issues/1639) from rasa/rasa/radare2x
- Merge pull request [#1635](https://github.com/ScoopInstaller/Scoop/issues/1635) from asmgf/patch-1
- Merge pull request [#1633](https://github.com/ScoopInstaller/Scoop/issues/1633) from plumps/patch-1
- Merge pull request [#1631](https://github.com/ScoopInstaller/Scoop/issues/1631) from asmgf/patch-1
- Merge pull request [#1624](https://github.com/ScoopInstaller/Scoop/issues/1624) from asmgf/patch-1
- Merge pull request [#1622](https://github.com/ScoopInstaller/Scoop/issues/1622) from rasa/rasa-revert
- Merge pull request [#1619](https://github.com/ScoopInstaller/Scoop/issues/1619) from rasa/rasa-sed
- Merge pull request [#1616](https://github.com/ScoopInstaller/Scoop/issues/1616) from rasa/rasa-file
- Merge pull request [#1617](https://github.com/ScoopInstaller/Scoop/issues/1617) from rasa/rasa-less
- Merge pull request [#1614](https://github.com/ScoopInstaller/Scoop/issues/1614) from rasa/rasa-qemu
- Merge pull request [#1608](https://github.com/ScoopInstaller/Scoop/issues/1608) from rasa/rasa-ripgrep
- Merge pull request [#1604](https://github.com/ScoopInstaller/Scoop/issues/1604) from liaoya/liaoyaUpdate
- Merge pull request [#1601](https://github.com/ScoopInstaller/Scoop/issues/1601) from rasa/rasa-rg
- Merge pull request [#1598](https://github.com/ScoopInstaller/Scoop/issues/1598) from narnaud/work/home
- Merge pull request [#1596](https://github.com/ScoopInstaller/Scoop/issues/1596) from rasa/rasa-qemu
- Merge pull request [#1597](https://github.com/ScoopInstaller/Scoop/issues/1597) from rasa/rasa-apache
- Merge pull request [#1595](https://github.com/ScoopInstaller/Scoop/issues/1595) from rasa/rasa-git-lfs2
- Merge pull request [#1594](https://github.com/ScoopInstaller/Scoop/issues/1594) from rasa/rasa-git-lfs
- Merge pull request [#1591](https://github.com/ScoopInstaller/Scoop/issues/1591) from rasa/exiftool
- Merge pull request [#1584](https://github.com/ScoopInstaller/Scoop/issues/1584) from rasa/master
- Merge pull request [#1582](https://github.com/ScoopInstaller/Scoop/issues/1582) from demesne/patch-1
- Merge pull request [#1578](https://github.com/ScoopInstaller/Scoop/issues/1578) from rasa/master
- Merge pull request [#1574](https://github.com/ScoopInstaller/Scoop/issues/1574) from asmgf/patch-1
- Merge pull request [#1575](https://github.com/ScoopInstaller/Scoop/issues/1575) from rasa/master
- Merge pull request [#1569](https://github.com/ScoopInstaller/Scoop/issues/1569) from rasa/master
- Merge pull request [#1568](https://github.com/ScoopInstaller/Scoop/issues/1568) from rasa/master
- Merge pull request [#1542](https://github.com/ScoopInstaller/Scoop/issues/1542) from TeaDrivenDev/clarify_status
- Merge pull request [#1561](https://github.com/ScoopInstaller/Scoop/issues/1561) from rasa/master
- Merge pull request [#1560](https://github.com/ScoopInstaller/Scoop/issues/1560) from swyphcosmo/master
- Merge pull request [#1557](https://github.com/ScoopInstaller/Scoop/issues/1557) from sskorol/feature/allure-version-update
- Merge pull request [#1531](https://github.com/ScoopInstaller/Scoop/issues/1531) from nueko/patch-2
- Merge pull request [#1517](https://github.com/ScoopInstaller/Scoop/issues/1517) from lukesampson/unix-compatible
- Merge pull request [#1520](https://github.com/ScoopInstaller/Scoop/issues/1520) from simonwjackson/patch-1
- Merge pull request [#1519](https://github.com/ScoopInstaller/Scoop/issues/1519) from nueko/patch-1
- Merge pull request [#1516](https://github.com/ScoopInstaller/Scoop/issues/1516) from se35710/issue-1514
- Merge pull request [#1513](https://github.com/ScoopInstaller/Scoop/issues/1513) from nueko/master
- Merge pull request [#1506](https://github.com/ScoopInstaller/Scoop/issues/1506) from nueko/patch-2
- Merge pull request [#1505](https://github.com/ScoopInstaller/Scoop/issues/1505) from wsw0108/master
- Merge pull request [#1500](https://github.com/ScoopInstaller/Scoop/issues/1500) from lguzzon/patch-1
- Merge pull request [#1496](https://github.com/ScoopInstaller/Scoop/issues/1496) from Alorel/patch-1
- Merge pull request [#1494](https://github.com/ScoopInstaller/Scoop/issues/1494) from se35710/master
- Merge pull request [#1489](https://github.com/ScoopInstaller/Scoop/issues/1489) from Alorel/patch-1
- Merge pull request [#1487](https://github.com/ScoopInstaller/Scoop/issues/1487) from Alorel/manifest/exiftool-10.52
- Merge pull request [#1486](https://github.com/ScoopInstaller/Scoop/issues/1486) from Alorel/manifest/flow-0.46.0
- Merge pull request [#1485](https://github.com/ScoopInstaller/Scoop/issues/1485) from Alorel/manifest/imagemagick-7.0.5-6
- Merge pull request [#1484](https://github.com/ScoopInstaller/Scoop/issues/1484) from Alorel/manifest/invoke-build-3.3.8
- Merge pull request [#1483](https://github.com/ScoopInstaller/Scoop/issues/1483) from Alorel/manifest/kubectl-1.6.3
- Merge pull request [#1482](https://github.com/ScoopInstaller/Scoop/issues/1482) from Alorel/manifest/nvm-1.1.4
- Merge pull request [#1481](https://github.com/ScoopInstaller/Scoop/issues/1481) from Alorel/manifest/postgresql-9.6.3
- Merge pull request [#1480](https://github.com/ScoopInstaller/Scoop/issues/1480) from Alorel/manifest/rg-0.5.2
- Merge pull request [#1479](https://github.com/ScoopInstaller/Scoop/issues/1479) from Alorel/manifest/terraform-0.9.5
- Merge pull request [#1478](https://github.com/ScoopInstaller/Scoop/issues/1478) from Alorel/manifest/upx-3.94
- Merge pull request [#1477](https://github.com/ScoopInstaller/Scoop/issues/1477) from Alorel/manifest/yarn-0.24.4
- Merge pull request [#1475](https://github.com/ScoopInstaller/Scoop/issues/1475) from Alorel/patch-1
- Merge pull request [#1465](https://github.com/ScoopInstaller/Scoop/issues/1465) from asmgf/patch-1
- Merge pull request [#1418](https://github.com/ScoopInstaller/Scoop/issues/1418) from rrelmy/tests
- Merge pull request [#1461](https://github.com/ScoopInstaller/Scoop/issues/1461) from markstephenq/master
- Merge pull request [#1458](https://github.com/ScoopInstaller/Scoop/issues/1458) from szachara/persist-quote-paths
- Merge pull request [#1455](https://github.com/ScoopInstaller/Scoop/issues/1455) from h404bi/patch-1
- Merge pull request [#1452](https://github.com/ScoopInstaller/Scoop/issues/1452) from klaidliadon/patch-1
- Merge pull request [#1448](https://github.com/ScoopInstaller/Scoop/issues/1448) from nightroman/master
- Merge pull request [#1447](https://github.com/ScoopInstaller/Scoop/issues/1447) from jinahya/master
- Merge pull request [#1444](https://github.com/ScoopInstaller/Scoop/issues/1444) from asmgf/patch-1
- Merge pull request [#1443](https://github.com/ScoopInstaller/Scoop/issues/1443) from altrive/fix-sbt-install
- Merge pull request [#1441](https://github.com/ScoopInstaller/Scoop/issues/1441) from MartyGentillon/master
- Merge pull request [#1437](https://github.com/ScoopInstaller/Scoop/issues/1437) from boazj/master
- Merge pull request [#1435](https://github.com/ScoopInstaller/Scoop/issues/1435) from asmgf/patch-1
- Merge pull request [#1432](https://github.com/ScoopInstaller/Scoop/issues/1432) from lukesampson/autoupdate-hashing
- Merge pull request [#1425](https://github.com/ScoopInstaller/Scoop/issues/1425) from nightroman/master
- Merge pull request [#1332](https://github.com/ScoopInstaller/Scoop/issues/1332) from lukesampson/install-specific-version
- Merge pull request [#1421](https://github.com/ScoopInstaller/Scoop/issues/1421) from Congee/master
- Merge pull request [#1419](https://github.com/ScoopInstaller/Scoop/issues/1419) from nightroman/master
- Merge pull request [#1410](https://github.com/ScoopInstaller/Scoop/issues/1410) from rrelmy/persist
- Merge pull request [#1414](https://github.com/ScoopInstaller/Scoop/issues/1414) from lukesampson/feature/checkver/remove-check-url
- Merge pull request [#1411](https://github.com/ScoopInstaller/Scoop/issues/1411) from nightroman/master
- Merge pull request [#1407](https://github.com/ScoopInstaller/Scoop/issues/1407) from fixablecar/patch-1
- Merge pull request [#1402](https://github.com/ScoopInstaller/Scoop/issues/1402) from Daniel15/yarn
- Merge pull request [#1399](https://github.com/ScoopInstaller/Scoop/issues/1399) from vidarkongsli/master
- Merge pull request [#1396](https://github.com/ScoopInstaller/Scoop/issues/1396) from inosik/update-dotnet
- Merge pull request [#1398](https://github.com/ScoopInstaller/Scoop/issues/1398) from nightroman/master
- Merge pull request [#1394](https://github.com/ScoopInstaller/Scoop/issues/1394) from tresf/master
- Merge pull request [#1392](https://github.com/ScoopInstaller/Scoop/issues/1392) from lukesampson/issue/[#1389](https://github.com/ScoopInstaller/Scoop/issues/1389)
- Merge pull request [#1393](https://github.com/ScoopInstaller/Scoop/issues/1393) from rrelmy/update-pshazz
- Merge pull request [#1385](https://github.com/ScoopInstaller/Scoop/issues/1385) from r15ch13/referer-header
- Merge pull request [#1390](https://github.com/ScoopInstaller/Scoop/issues/1390) from nightroman/master
- Merge pull request [#1387](https://github.com/ScoopInstaller/Scoop/issues/1387) from juliostanley/master
- Merge pull request [#1386](https://github.com/ScoopInstaller/Scoop/issues/1386) from yunspace/remove_home
- Merge pull request [#1379](https://github.com/ScoopInstaller/Scoop/issues/1379) from asmgf/patch-1
- Merge pull request [#1373](https://github.com/ScoopInstaller/Scoop/issues/1373) from nightroman/master
- Merge pull request [#1369](https://github.com/ScoopInstaller/Scoop/issues/1369) from rrelmy/master
- Merge pull request [#1365](https://github.com/ScoopInstaller/Scoop/issues/1365) from bpollack/master
- Merge pull request [#1364](https://github.com/ScoopInstaller/Scoop/issues/1364) from wangzq/feature/override-cachepath
- Merge pull request [#1361](https://github.com/ScoopInstaller/Scoop/issues/1361) from rasa/master
- Merge pull request [#1362](https://github.com/ScoopInstaller/Scoop/issues/1362) from r15ch13/jsonpath
- Merge pull request [#1360](https://github.com/ScoopInstaller/Scoop/issues/1360) from r15ch13/au-errorhandling
- Merge pull request [#1356](https://github.com/ScoopInstaller/Scoop/issues/1356) from nightroman/master
- Merge pull request [#1353](https://github.com/ScoopInstaller/Scoop/issues/1353) from rasa/master
- Merge pull request [#1352](https://github.com/ScoopInstaller/Scoop/issues/1352) from r15ch13/cacert
- Merge pull request [#1351](https://github.com/ScoopInstaller/Scoop/issues/1351) from bpollack/master
- Merge pull request [#1350](https://github.com/ScoopInstaller/Scoop/issues/1350) from rasa/master
- Merge pull request [#1345](https://github.com/ScoopInstaller/Scoop/issues/1345) from nightroman/master
- Merge pull request [#1343](https://github.com/ScoopInstaller/Scoop/issues/1343) from fireashes/patch-1
- Merge pull request [#1342](https://github.com/ScoopInstaller/Scoop/issues/1342) from r15ch13/schema
- Merge pull request [#1339](https://github.com/ScoopInstaller/Scoop/issues/1339) from alvin-nt/postgresql-pgadmin-fix
- Merge pull request [#1340](https://github.com/ScoopInstaller/Scoop/issues/1340) from tehbilly/master
- Merge pull request [#1341](https://github.com/ScoopInstaller/Scoop/issues/1341) from rasa/patch-2
- Merge pull request [#1337](https://github.com/ScoopInstaller/Scoop/issues/1337) from inosik/suggest-nodejs-lts
- Merge pull request [#1335](https://github.com/ScoopInstaller/Scoop/issues/1335) from sestegra/dart
- Merge pull request [#1333](https://github.com/ScoopInstaller/Scoop/issues/1333) from phitsc/master
- Merge pull request [#1329](https://github.com/ScoopInstaller/Scoop/issues/1329) from lukesampson/dl-refactor
- Merge pull request [#1327](https://github.com/ScoopInstaller/Scoop/issues/1327) from sestegra/docker
- Merge pull request [#1326](https://github.com/ScoopInstaller/Scoop/issues/1326) from sestegra/docker
- Merge pull request [#1325](https://github.com/ScoopInstaller/Scoop/issues/1325) from sestegra/docker
- Merge pull request [#1323](https://github.com/ScoopInstaller/Scoop/issues/1323) from rasa/patch-1
- Merge pull request [#1322](https://github.com/ScoopInstaller/Scoop/issues/1322) from rasa/master
- Merge pull request [#1321](https://github.com/ScoopInstaller/Scoop/issues/1321) from rrelmy/update-imagemagick
- Merge pull request [#1303](https://github.com/ScoopInstaller/Scoop/issues/1303) from rasa/master
- Merge pull request [#1318](https://github.com/ScoopInstaller/Scoop/issues/1318) from r15ch13/manifest/git-2.11.1.windows.1
- Merge pull request [#1317](https://github.com/ScoopInstaller/Scoop/issues/1317) from r15ch13/manifest/git-with-openssh-2.11.1.windows.1
- Merge pull request [#1316](https://github.com/ScoopInstaller/Scoop/issues/1316) from r15ch13/manifest/bfg-1.12.15
- Merge pull request [#1314](https://github.com/ScoopInstaller/Scoop/issues/1314) from r15ch13/upx
- Merge pull request [#1313](https://github.com/ScoopInstaller/Scoop/issues/1313) from r15ch13/tests-fix
- Merge pull request [#1308](https://github.com/ScoopInstaller/Scoop/issues/1308) from r15ch13/manifest/ffmpeg-20170202-08b0981
- Merge pull request [#1309](https://github.com/ScoopInstaller/Scoop/issues/1309) from r15ch13/manifest/mercurial-4.1
- Merge pull request [#1310](https://github.com/ScoopInstaller/Scoop/issues/1310) from r15ch13/manifest/rust-msvc-1.15.0
- Merge pull request [#1311](https://github.com/ScoopInstaller/Scoop/issues/1311) from r15ch13/manifest/rust-1.15.0
- Merge pull request [#1312](https://github.com/ScoopInstaller/Scoop/issues/1312) from r15ch13/manifest/yarn-0.19.1
- Merge pull request [#1307](https://github.com/ScoopInstaller/Scoop/issues/1307) from dvushok/master
- Merge pull request [#1306](https://github.com/ScoopInstaller/Scoop/issues/1306) from sestegra/docker
- Merge pull request [#1305](https://github.com/ScoopInstaller/Scoop/issues/1305) from inosik/nuget-head-requests
- Merge pull request [#1304](https://github.com/ScoopInstaller/Scoop/issues/1304) from r15ch13/manifest/openjdk-1.8.0.121-1
- Merge pull request [#1300](https://github.com/ScoopInstaller/Scoop/issues/1300) from r15ch13/manifest/rancher-compose-0.12.2
- Merge pull request [#1301](https://github.com/ScoopInstaller/Scoop/issues/1301) from r15ch13/manifest/youtube-dl-2017.02.01
- Merge pull request [#1302](https://github.com/ScoopInstaller/Scoop/issues/1302) from r15ch13/manifest/openjdk-fix
- Merge pull request [#1298](https://github.com/ScoopInstaller/Scoop/issues/1298) from r15ch13/manifest/nodejs-lts-6.9.5
- Merge pull request [#1299](https://github.com/ScoopInstaller/Scoop/issues/1299) from r15ch13/manifest/nodejs-7.5.0
- Merge pull request [#1296](https://github.com/ScoopInstaller/Scoop/issues/1296) from r15ch13/manifest/grails-3.2.5
- Merge pull request [#1295](https://github.com/ScoopInstaller/Scoop/issues/1295) from r15ch13/auto-pr
- Merge pull request [#1292](https://github.com/ScoopInstaller/Scoop/issues/1292) from mrkishi/no-search-results
- Merge pull request [#1287](https://github.com/ScoopInstaller/Scoop/issues/1287) from r15ch13/fix-ps3
- Merge pull request [#1285](https://github.com/ScoopInstaller/Scoop/issues/1285) from r15ch13/youtube-dl-2017.01.29
- Merge pull request [#1280](https://github.com/ScoopInstaller/Scoop/issues/1280) from r15ch13/ffmpeg-20170130-cba4f0e
- Merge pull request [#1284](https://github.com/ScoopInstaller/Scoop/issues/1284) from r15ch13/yarn-0.20.0
- Merge pull request [#1281](https://github.com/ScoopInstaller/Scoop/issues/1281) from r15ch13/go-1.7.5
- Merge pull request [#1282](https://github.com/ScoopInstaller/Scoop/issues/1282) from r15ch13/imagemagick-7.0.4-6
- Merge pull request [#1283](https://github.com/ScoopInstaller/Scoop/issues/1283) from r15ch13/latex-2.9.6236
- Merge pull request [#1279](https://github.com/ScoopInstaller/Scoop/issues/1279) from mrkishi/reset-error
- Merge pull request [#1275](https://github.com/ScoopInstaller/Scoop/issues/1275) from martinlindhe/radare
- Merge pull request [#1274](https://github.com/ScoopInstaller/Scoop/issues/1274) from jfmherokiller/patch-1
- Merge pull request [#1272](https://github.com/ScoopInstaller/Scoop/issues/1272) from rasa/master
- Merge pull request [#1265](https://github.com/ScoopInstaller/Scoop/issues/1265) from r15ch13/caddy-0.9.5
- Merge pull request [#1266](https://github.com/ScoopInstaller/Scoop/issues/1266) from r15ch13/elixir-1.4.1
- Merge pull request [#1267](https://github.com/ScoopInstaller/Scoop/issues/1267) from r15ch13/ffmpeg-20170125-2080bc3
- Merge pull request [#1268](https://github.com/ScoopInstaller/Scoop/issues/1268) from r15ch13/nginx-1.11.9
- Merge pull request [#1269](https://github.com/ScoopInstaller/Scoop/issues/1269) from r15ch13/racket-6.8
- Merge pull request [#1270](https://github.com/ScoopInstaller/Scoop/issues/1270) from r15ch13/terraform-0.8.5
- Merge pull request [#1271](https://github.com/ScoopInstaller/Scoop/issues/1271) from r15ch13/youtube-dl-2017.01.25
- Merge pull request [#1264](https://github.com/ScoopInstaller/Scoop/issues/1264) from rasa/master
- Merge pull request [#1262](https://github.com/ScoopInstaller/Scoop/issues/1262) from bpollack/master
- Merge pull request [#1258](https://github.com/ScoopInstaller/Scoop/issues/1258) from rasa/master
- Merge pull request [#1255](https://github.com/ScoopInstaller/Scoop/issues/1255) from r15ch13/ffmpeg-20170123-e371f03
- Merge pull request [#1254](https://github.com/ScoopInstaller/Scoop/issues/1254) from darthwalsh/patch-1
- Merge pull request [#1252](https://github.com/ScoopInstaller/Scoop/issues/1252) from r15ch13/youtube-dl-2017.01.22
- Merge pull request [#1251](https://github.com/ScoopInstaller/Scoop/issues/1251) from r15ch13/forge-1.4.0
- Merge pull request [#1248](https://github.com/ScoopInstaller/Scoop/issues/1248) from zweimal/patch-1
- Merge pull request [#1247](https://github.com/ScoopInstaller/Scoop/issues/1247) from r15ch13/ffmpeg-20170121-d60f090
- Merge pull request [#1245](https://github.com/ScoopInstaller/Scoop/issues/1245) from r15ch13/rocket
- Merge pull request [#1244](https://github.com/ScoopInstaller/Scoop/issues/1244) from r15ch13/youtube-dl-2017.01.18
- Merge pull request [#1243](https://github.com/ScoopInstaller/Scoop/issues/1243) from r15ch13/php-nts-7.1.1
- Merge pull request [#1238](https://github.com/ScoopInstaller/Scoop/issues/1238) from r15ch13/flow-0.38.0
- Merge pull request [#1239](https://github.com/ScoopInstaller/Scoop/issues/1239) from r15ch13/grails-3.1.15
- Merge pull request [#1240](https://github.com/ScoopInstaller/Scoop/issues/1240) from r15ch13/imagemagick-7.0.4-5
- Merge pull request [#1242](https://github.com/ScoopInstaller/Scoop/issues/1242) from r15ch13/packer-0.12.2
- Merge pull request [#1241](https://github.com/ScoopInstaller/Scoop/issues/1241) from r15ch13/mariadb-10.1.21
- Merge pull request [#1235](https://github.com/ScoopInstaller/Scoop/issues/1235) from martinlindhe/php
- Merge pull request [#1234](https://github.com/ScoopInstaller/Scoop/issues/1234) from gjmveloso/update/resharper-2016.3
- Merge pull request [#1231](https://github.com/ScoopInstaller/Scoop/issues/1231) from r15ch13/docker-autoupdate
- Merge pull request [#1232](https://github.com/ScoopInstaller/Scoop/issues/1232) from r15ch13/ffmpeg-20170117-f7e9275
- Merge pull request [#1233](https://github.com/ScoopInstaller/Scoop/issues/1233) from sestegra/docker
- Merge pull request [#1230](https://github.com/ScoopInstaller/Scoop/issues/1230) from sestegra/docker
- Merge pull request [#1229](https://github.com/ScoopInstaller/Scoop/issues/1229) from sestegra/docker
- Merge pull request [#1228](https://github.com/ScoopInstaller/Scoop/issues/1228) from r15ch13/auto-pr
- Merge pull request [#1227](https://github.com/ScoopInstaller/Scoop/issues/1227) from r15ch13/openjdk-autoupdate
- Merge pull request [#1226](https://github.com/ScoopInstaller/Scoop/issues/1226) from r15ch13/more-substitutions
- Merge pull request [#1225](https://github.com/ScoopInstaller/Scoop/issues/1225) from r15ch13/hashicorp
- Merge pull request [#1223](https://github.com/ScoopInstaller/Scoop/issues/1223) from sestegra/dart-sass
- Merge pull request [#1224](https://github.com/ScoopInstaller/Scoop/issues/1224) from r15ch13/yarn-0.19.1
- Merge pull request [#1215](https://github.com/ScoopInstaller/Scoop/issues/1215) from r15ch13/git
- Merge pull request [#1217](https://github.com/ScoopInstaller/Scoop/issues/1217) from r15ch13/ffmpeg-20170116-e664730
- Merge pull request [#1218](https://github.com/ScoopInstaller/Scoop/issues/1218) from r15ch13/syncany-cli-0.4.9
- Merge pull request [#1219](https://github.com/ScoopInstaller/Scoop/issues/1219) from r15ch13/youtube-dl-2017.01.16
- Merge pull request [#1212](https://github.com/ScoopInstaller/Scoop/issues/1212) from martinlindhe/master
- Merge pull request [#1211](https://github.com/ScoopInstaller/Scoop/issues/1211) from r15ch13/regex-version-templates
- Merge pull request [#1210](https://github.com/ScoopInstaller/Scoop/issues/1210) from r15ch13/update
- Merge pull request [#1209](https://github.com/ScoopInstaller/Scoop/issues/1209) from sestegra/dart
- Merge pull request [#1208](https://github.com/ScoopInstaller/Scoop/issues/1208) from r15ch13/version-templates
- Merge pull request [#1207](https://github.com/ScoopInstaller/Scoop/issues/1207) from rasa/fix-schema
- Merge pull request [#1206](https://github.com/ScoopInstaller/Scoop/issues/1206) from r15ch13/updates
- Merge pull request [#1205](https://github.com/ScoopInstaller/Scoop/issues/1205) from sestegra/docker
- Merge pull request [#1204](https://github.com/ScoopInstaller/Scoop/issues/1204) from r15ch13/adb
- Merge pull request [#1201](https://github.com/ScoopInstaller/Scoop/issues/1201) from moigagoo/patch-19
- Merge pull request [#1200](https://github.com/ScoopInstaller/Scoop/issues/1200) from martinlindhe/gdb
- Merge pull request [#1199](https://github.com/ScoopInstaller/Scoop/issues/1199) from rrelmy/updates-2017-01-08
- Merge pull request [#1192](https://github.com/ScoopInstaller/Scoop/issues/1192) from rasa/master
- Merge pull request [#1193](https://github.com/ScoopInstaller/Scoop/issues/1193) from Krzysztof-Cieslak/patch-1
- Merge pull request [#1194](https://github.com/ScoopInstaller/Scoop/issues/1194) from zeero/lzh_support
- Merge pull request [#1190](https://github.com/ScoopInstaller/Scoop/issues/1190) from rasa/master
- Merge pull request [#1189](https://github.com/ScoopInstaller/Scoop/issues/1189) from martinlindhe/master
- Merge pull request [#1187](https://github.com/ScoopInstaller/Scoop/issues/1187) from asmundg/git-gcm
- Merge pull request [#1188](https://github.com/ScoopInstaller/Scoop/issues/1188) from rasa/master
- Merge pull request [#1186](https://github.com/ScoopInstaller/Scoop/issues/1186) from rrelmy/autoupdate
- Merge pull request [#1183](https://github.com/ScoopInstaller/Scoop/issues/1183) from rasa/master
- Merge pull request [#1182](https://github.com/ScoopInstaller/Scoop/issues/1182) from rasa/master
- Merge pull request [#1181](https://github.com/ScoopInstaller/Scoop/issues/1181) from rasa/master
- Merge pull request [#1178](https://github.com/ScoopInstaller/Scoop/issues/1178) from yunspace/master
- Merge pull request [#1177](https://github.com/ScoopInstaller/Scoop/issues/1177) from yunspace/master
- Merge pull request [#1174](https://github.com/ScoopInstaller/Scoop/issues/1174) from mikhail-tsennykh/patch-1
- Merge pull request [#1175](https://github.com/ScoopInstaller/Scoop/issues/1175) from yunspace/master
- Merge pull request [#1176](https://github.com/ScoopInstaller/Scoop/issues/1176) from dvushok/master
- Merge pull request [#1173](https://github.com/ScoopInstaller/Scoop/issues/1173) from moigagoo/patch-18
- Merge pull request [#1171](https://github.com/ScoopInstaller/Scoop/issues/1171) from joe-chung/patch-1
- Merge pull request [#1172](https://github.com/ScoopInstaller/Scoop/issues/1172) from joe-chung/patch-2
- Merge pull request [#1167](https://github.com/ScoopInstaller/Scoop/issues/1167) from icetee/master
- Merge pull request [#1](https://github.com/ScoopInstaller/Scoop/issues/1) from lukesampson/master
- Merge pull request [#1166](https://github.com/ScoopInstaller/Scoop/issues/1166) from asmundg/git-bash
- Merge pull request [#1165](https://github.com/ScoopInstaller/Scoop/issues/1165) from vidarkongsli/update/apache
- Merge pull request [#1164](https://github.com/ScoopInstaller/Scoop/issues/1164) from Krzysztof-Cieslak/patch-1
- Merge pull request [#1160](https://github.com/ScoopInstaller/Scoop/issues/1160) from deepakSP/master
- Merge pull request [#1161](https://github.com/ScoopInstaller/Scoop/issues/1161) from johlrich/patch-1
- Merge pull request [#1159](https://github.com/ScoopInstaller/Scoop/issues/1159) from deepakSP/master
- Merge pull request [#1158](https://github.com/ScoopInstaller/Scoop/issues/1158) from sestegra/docker
- Merge pull request [#1157](https://github.com/ScoopInstaller/Scoop/issues/1157) from asmgf/patch-2
- Merge pull request [#1155](https://github.com/ScoopInstaller/Scoop/issues/1155) from deepakSP/master
- Merge pull request [#1153](https://github.com/ScoopInstaller/Scoop/issues/1153) from sestegra/docker
- Merge pull request [#1152](https://github.com/ScoopInstaller/Scoop/issues/1152) from nightroman/master
- Merge pull request [#1150](https://github.com/ScoopInstaller/Scoop/issues/1150) from rrelmy/autoupdate
- Merge pull request [#1147](https://github.com/ScoopInstaller/Scoop/issues/1147) from koseduhemak/master
- Merge pull request [#1146](https://github.com/ScoopInstaller/Scoop/issues/1146) from sestegra/dart
- Merge pull request [#1145](https://github.com/ScoopInstaller/Scoop/issues/1145) from inosik/update-git
- Merge pull request [#1144](https://github.com/ScoopInstaller/Scoop/issues/1144) from moigagoo/patch-17
- Merge pull request [#1136](https://github.com/ScoopInstaller/Scoop/issues/1136) from rrelmy/update-imagemagick
- Merge pull request [#1137](https://github.com/ScoopInstaller/Scoop/issues/1137) from Krzysztof-Cieslak/patch-1
- Merge pull request [#1135](https://github.com/ScoopInstaller/Scoop/issues/1135) from icetee/master
- Merge pull request [#1133](https://github.com/ScoopInstaller/Scoop/issues/1133) from moigagoo/patch-16
- Merge pull request [#1132](https://github.com/ScoopInstaller/Scoop/issues/1132) from nrakochy/master
- Merge pull request [#1131](https://github.com/ScoopInstaller/Scoop/issues/1131) from vidarkongsli/master
- Merge pull request [#1130](https://github.com/ScoopInstaller/Scoop/issues/1130) from sestegra/docker
- Merge pull request [#974](https://github.com/ScoopInstaller/Scoop/issues/974) from yunspace/master
- Merge pull request [#853](https://github.com/ScoopInstaller/Scoop/issues/853) from monotykamary/patch-1
- Merge pull request [#810](https://github.com/ScoopInstaller/Scoop/issues/810) from monotykamary/patch-4
- Merge pull request [#789](https://github.com/ScoopInstaller/Scoop/issues/789) from sestegra/docker
- Merge pull request [#788](https://github.com/ScoopInstaller/Scoop/issues/788) from chrjean/patch-8
- Merge pull request [#786](https://github.com/ScoopInstaller/Scoop/issues/786) from lukesampson/revert-781-master
- Merge pull request [#782](https://github.com/ScoopInstaller/Scoop/issues/782) from Cyianor/master
- Merge pull request [#781](https://github.com/ScoopInstaller/Scoop/issues/781) from parthopdas/master
- Merge pull request [#779](https://github.com/ScoopInstaller/Scoop/issues/779) from Cyianor/master
- Merge pull request [#780](https://github.com/ScoopInstaller/Scoop/issues/780) from kyungminlee/master
- Merge pull request [#778](https://github.com/ScoopInstaller/Scoop/issues/778) from vidarkongsli/master
- Merge pull request [#776](https://github.com/ScoopInstaller/Scoop/issues/776) from chrjean/patch-7
- Merge pull request [#775](https://github.com/ScoopInstaller/Scoop/issues/775) from Ardakilic/master
- Merge pull request [#772](https://github.com/ScoopInstaller/Scoop/issues/772) from chrjean/patch-5
- Merge pull request [#771](https://github.com/ScoopInstaller/Scoop/issues/771) from chrjean/patch-6
- Merge pull request [#770](https://github.com/ScoopInstaller/Scoop/issues/770) from Ardakilic/patch-1
- Merge pull request [#769](https://github.com/ScoopInstaller/Scoop/issues/769) from MPLew-is/master
- Merge pull request [#768](https://github.com/ScoopInstaller/Scoop/issues/768) from saildata/master
- Merge pull request [#766](https://github.com/ScoopInstaller/Scoop/issues/766) from MPLew-is/php-apache-visual-c-dependency
- Merge pull request [#764](https://github.com/ScoopInstaller/Scoop/issues/764) from neoeinstein/update-git-lfs
- Merge pull request [#765](https://github.com/ScoopInstaller/Scoop/issues/765) from neoeinstein/update-git
- Merge pull request [#762](https://github.com/ScoopInstaller/Scoop/issues/762) from neoeinstein/promote-latex
- Merge pull request [#761](https://github.com/ScoopInstaller/Scoop/issues/761) from neoeinstein/promote-hashicorp
- Merge pull request [#760](https://github.com/ScoopInstaller/Scoop/issues/760) from neoeinstein/promote-rancher-compose
- Merge pull request [#758](https://github.com/ScoopInstaller/Scoop/issues/758) from neoeinstein/bugfix-shortcut-uninstall
- Merge pull request [#757](https://github.com/ScoopInstaller/Scoop/issues/757) from MPLew-is/master
- Merge pull request [#756](https://github.com/ScoopInstaller/Scoop/issues/756) from MPLew-is/master
- Merge pull request [#755](https://github.com/ScoopInstaller/Scoop/issues/755) from MPLew-is/php-apache-dependencies
- Merge pull request [#754](https://github.com/ScoopInstaller/Scoop/issues/754) from MPLew-is/master
- Merge pull request [#752](https://github.com/ScoopInstaller/Scoop/issues/752) from Mika-/master
- Merge pull request [#751](https://github.com/ScoopInstaller/Scoop/issues/751) from chrjean/patch-5
- Merge pull request [#749](https://github.com/ScoopInstaller/Scoop/issues/749) from MPLew-is/master
- Merge pull request [#748](https://github.com/ScoopInstaller/Scoop/issues/748) from MPLew-is/master
- Merge pull request [#747](https://github.com/ScoopInstaller/Scoop/issues/747) from aaronzs/patch-1
- Merge pull request [#746](https://github.com/ScoopInstaller/Scoop/issues/746) from berwyn/master
- Merge pull request [#745](https://github.com/ScoopInstaller/Scoop/issues/745) from chrjean/patch-4
- Merge pull request [#744](https://github.com/ScoopInstaller/Scoop/issues/744) from joe-chung/patch-1
- Merge pull request [#742](https://github.com/ScoopInstaller/Scoop/issues/742) from joe-chung/patch-1
- Merge pull request [#739](https://github.com/ScoopInstaller/Scoop/issues/739) from william-ellis/feature/nodejs-5.8.0
- Merge pull request [#741](https://github.com/ScoopInstaller/Scoop/issues/741) from william-ellis/feature/mongodb-3.2.4
- Merge pull request [#738](https://github.com/ScoopInstaller/Scoop/issues/738) from joe-chung/patch-1
- Merge pull request [#736](https://github.com/ScoopInstaller/Scoop/issues/736) from sestegra/docker
- Merge pull request [#735](https://github.com/ScoopInstaller/Scoop/issues/735) from saildata/master
- Merge pull request [#733](https://github.com/ScoopInstaller/Scoop/issues/733) from dcastro/scala-2.11.8
- Merge pull request [#734](https://github.com/ScoopInstaller/Scoop/issues/734) from sestegra/dart
- Merge pull request [#731](https://github.com/ScoopInstaller/Scoop/issues/731) from nightroman/master
- Merge pull request [#729](https://github.com/ScoopInstaller/Scoop/issues/729) from william-ellis/new-app/ack
- Merge pull request [#730](https://github.com/ScoopInstaller/Scoop/issues/730) from william-ellis/update/mongodb
- Merge pull request [#728](https://github.com/ScoopInstaller/Scoop/issues/728) from chrjean/patch-2
- Merge pull request [#727](https://github.com/ScoopInstaller/Scoop/issues/727) from joe-chung/patch-2
- Merge pull request [#726](https://github.com/ScoopInstaller/Scoop/issues/726) from joe-chung/patch-1
- Merge pull request [#725](https://github.com/ScoopInstaller/Scoop/issues/725) from iakio/php-7.0.4
- Merge pull request [#724](https://github.com/ScoopInstaller/Scoop/issues/724) from chrjean/patch-1
- Merge pull request [#723](https://github.com/ScoopInstaller/Scoop/issues/723) from klaidliadon/patch-1
- Merge pull request [#722](https://github.com/ScoopInstaller/Scoop/issues/722) from h404bi/patch-1
- Merge pull request [#720](https://github.com/ScoopInstaller/Scoop/issues/720) from smudge/patch-1
- Merge pull request [#718](https://github.com/ScoopInstaller/Scoop/issues/718) from joe-chung/patch-1
- Merge pull request [#716](https://github.com/ScoopInstaller/Scoop/issues/716) from sakai135/patch-2
- Merge pull request [#717](https://github.com/ScoopInstaller/Scoop/issues/717) from sakai135/patch-3
- Merge pull request [#715](https://github.com/ScoopInstaller/Scoop/issues/715) from Krzysztof-Cieslak/patch-1
- Merge pull request [#713](https://github.com/ScoopInstaller/Scoop/issues/713) from joe-chung/patch-1
- Merge pull request [#714](https://github.com/ScoopInstaller/Scoop/issues/714) from joe-chung/patch-2
- Merge pull request [#709](https://github.com/ScoopInstaller/Scoop/issues/709) from nilkesede/master
- Merge pull request [#711](https://github.com/ScoopInstaller/Scoop/issues/711) from joe-chung/patch-1
- Merge pull request [#712](https://github.com/ScoopInstaller/Scoop/issues/712) from joe-chung/patch-2
- Merge pull request [#708](https://github.com/ScoopInstaller/Scoop/issues/708) from joe-chung/patch-1
- Merge pull request [#707](https://github.com/ScoopInstaller/Scoop/issues/707) from aaronzs/patch-2
- Merge pull request [#706](https://github.com/ScoopInstaller/Scoop/issues/706) from robyrobrob/patch-2
- Merge pull request [#704](https://github.com/ScoopInstaller/Scoop/issues/704) from sakai135/patch-1
- Merge pull request [#703](https://github.com/ScoopInstaller/Scoop/issues/703) from kmorin/update/mongo-update
- Merge pull request [#702](https://github.com/ScoopInstaller/Scoop/issues/702) from robyrobrob/patch-1
- Merge pull request [#1](https://github.com/ScoopInstaller/Scoop/issues/1) from kmorin/kmorin-patch-1
- Merge pull request [#701](https://github.com/ScoopInstaller/Scoop/issues/701) from joe-chung/patch-2
- Merge pull request [#700](https://github.com/ScoopInstaller/Scoop/issues/700) from joe-chung/patch-1
- Merge pull request [#698](https://github.com/ScoopInstaller/Scoop/issues/698) from nilkesede/master
- Merge pull request [#699](https://github.com/ScoopInstaller/Scoop/issues/699) from joe-chung/patch-1
- Merge pull request [#696](https://github.com/ScoopInstaller/Scoop/issues/696) from Simon-Campbell/patch-1
- Merge pull request [#694](https://github.com/ScoopInstaller/Scoop/issues/694) from saildata/master
- Merge pull request [#693](https://github.com/ScoopInstaller/Scoop/issues/693) from deecewan/master
- Merge pull request [#692](https://github.com/ScoopInstaller/Scoop/issues/692) from damnhandy/master
- Merge pull request [#691](https://github.com/ScoopInstaller/Scoop/issues/691) from cloudRoutine/patch-3
- Merge pull request [#690](https://github.com/ScoopInstaller/Scoop/issues/690) from cloudRoutine/patch-1
- Merge pull request [#689](https://github.com/ScoopInstaller/Scoop/issues/689) from Mika-/master
- Merge pull request [#688](https://github.com/ScoopInstaller/Scoop/issues/688) from sakai135/patch-25
- Merge pull request [#686](https://github.com/ScoopInstaller/Scoop/issues/686) from Krzysztof-Cieslak/patch-1
- Merge pull request [#684](https://github.com/ScoopInstaller/Scoop/issues/684) from aaronzs/patch-1
- Merge pull request [#683](https://github.com/ScoopInstaller/Scoop/issues/683) from sestegra/dart
- Merge pull request [#680](https://github.com/ScoopInstaller/Scoop/issues/680) from sakai135/patch-23
- Merge pull request [#681](https://github.com/ScoopInstaller/Scoop/issues/681) from sakai135/patch-24
- Merge pull request [#679](https://github.com/ScoopInstaller/Scoop/issues/679) from damnhandy/startmenu_icon
- Merge pull request [#677](https://github.com/ScoopInstaller/Scoop/issues/677) from sakai135/patch-22
- Merge pull request [#676](https://github.com/ScoopInstaller/Scoop/issues/676) from sakai135/patch-21
- Merge pull request [#675](https://github.com/ScoopInstaller/Scoop/issues/675) from sakai135/patch-20
- Merge pull request [#672](https://github.com/ScoopInstaller/Scoop/issues/672) from saildata/master
- Merge pull request [#674](https://github.com/ScoopInstaller/Scoop/issues/674) from sestegra/dart
- Merge pull request [#670](https://github.com/ScoopInstaller/Scoop/issues/670) from moigagoo/patch-19
- Merge pull request [#669](https://github.com/ScoopInstaller/Scoop/issues/669) from damnhandy/master
- Merge pull request [#667](https://github.com/ScoopInstaller/Scoop/issues/667) from damnhandy/master
- Merge pull request [#665](https://github.com/ScoopInstaller/Scoop/issues/665) from sestegra/dart
- Merge pull request [#664](https://github.com/ScoopInstaller/Scoop/issues/664) from nikolaia/patch-2
- Merge pull request [#662](https://github.com/ScoopInstaller/Scoop/issues/662) from vsafin-copart/patch-1
- Merge pull request [#661](https://github.com/ScoopInstaller/Scoop/issues/661) from engelhro/engelhro-update
- Merge pull request [#3](https://github.com/ScoopInstaller/Scoop/issues/3) from lukesampson/master
- Merge pull request [#659](https://github.com/ScoopInstaller/Scoop/issues/659) from lukesampson/feature/bucket-install
- Merge pull request [#658](https://github.com/ScoopInstaller/Scoop/issues/658) from lukesampson/feature/bucket-remote-search
- Merge pull request [#657](https://github.com/ScoopInstaller/Scoop/issues/657) from damnhandy/master
- Merge pull request [#656](https://github.com/ScoopInstaller/Scoop/issues/656) from belisarh/patch-1
- Merge pull request [#654](https://github.com/ScoopInstaller/Scoop/issues/654) from engelhro/patch-1
- Merge pull request [#655](https://github.com/ScoopInstaller/Scoop/issues/655) from engelhro/patch-2
- Merge pull request [#643](https://github.com/ScoopInstaller/Scoop/issues/643) from lukesampson/feature/lessmsi-install
- Merge pull request [#653](https://github.com/ScoopInstaller/Scoop/issues/653) from engelhro/engelhro-additions
- Merge pull request [#652](https://github.com/ScoopInstaller/Scoop/issues/652) from engelhro/engelhro-update
- Merge pull request [#2](https://github.com/ScoopInstaller/Scoop/issues/2) from lukesampson/master
- Merge pull request [#1](https://github.com/ScoopInstaller/Scoop/issues/1) from lukesampson/master
- Merge pull request [#651](https://github.com/ScoopInstaller/Scoop/issues/651) from engelhro/engelhro-update
- Merge pull request [#650](https://github.com/ScoopInstaller/Scoop/issues/650) from sakai135/patch-19
- Merge pull request [#649](https://github.com/ScoopInstaller/Scoop/issues/649) from sakai135/patch-18
- Merge pull request [#648](https://github.com/ScoopInstaller/Scoop/issues/648) from engelhro/patch-7
- Merge pull request [#647](https://github.com/ScoopInstaller/Scoop/issues/647) from engelhro/patch-6
- Merge pull request [#646](https://github.com/ScoopInstaller/Scoop/issues/646) from engelhro/patch-5
- Merge pull request [#645](https://github.com/ScoopInstaller/Scoop/issues/645) from engelhro/patch-3
- Merge pull request [#644](https://github.com/ScoopInstaller/Scoop/issues/644) from engelhro/patch-1
- Merge pull request [#640](https://github.com/ScoopInstaller/Scoop/issues/640) from aaronzs/git-with-openssh-test
- Merge pull request [#639](https://github.com/ScoopInstaller/Scoop/issues/639) from lukesampson/revert-637-revert-636-revert-635-patch-1
- Merge pull request [#637](https://github.com/ScoopInstaller/Scoop/issues/637) from lukesampson/revert-636-revert-635-patch-1
- Merge pull request [#636](https://github.com/ScoopInstaller/Scoop/issues/636) from lukesampson/revert-635-patch-1
- Merge pull request [#635](https://github.com/ScoopInstaller/Scoop/issues/635) from aaronzs/patch-1
- Merge pull request [#632](https://github.com/ScoopInstaller/Scoop/issues/632) from aaronzs/patch-1
- Merge pull request [#630](https://github.com/ScoopInstaller/Scoop/issues/630) from sestegra/patch-1
- Merge pull request [#628](https://github.com/ScoopInstaller/Scoop/issues/628) from damnhandy/master
- Merge pull request [#627](https://github.com/ScoopInstaller/Scoop/issues/627) from dhayab/master
- Merge pull request [#624](https://github.com/ScoopInstaller/Scoop/issues/624) from aaronzs/patch-1
- Merge pull request [#626](https://github.com/ScoopInstaller/Scoop/issues/626) from lukesampson/feature/7zip-15.14
- Merge pull request [#623](https://github.com/ScoopInstaller/Scoop/issues/623) from berwyn/master
- Merge pull request [#621](https://github.com/ScoopInstaller/Scoop/issues/621) from japhar81/master
- Merge pull request [#617](https://github.com/ScoopInstaller/Scoop/issues/617) from sestegra/dart
- Merge pull request [#618](https://github.com/ScoopInstaller/Scoop/issues/618) from sakai135/patch-15
- Merge pull request [#619](https://github.com/ScoopInstaller/Scoop/issues/619) from sakai135/patch-16
- Merge pull request [#620](https://github.com/ScoopInstaller/Scoop/issues/620) from sakai135/patch-17
- Merge pull request [#614](https://github.com/ScoopInstaller/Scoop/issues/614) from pongstr/master
- Merge pull request [#613](https://github.com/ScoopInstaller/Scoop/issues/613) from jmoles/master
- Merge pull request [#612](https://github.com/ScoopInstaller/Scoop/issues/612) from nightroman/master
- Merge pull request [#611](https://github.com/ScoopInstaller/Scoop/issues/611) from sestegra/dart
- Merge pull request [#610](https://github.com/ScoopInstaller/Scoop/issues/610) from thomaskonrad/master
- Merge pull request [#608](https://github.com/ScoopInstaller/Scoop/issues/608) from maman/patch-1
- Merge pull request [#606](https://github.com/ScoopInstaller/Scoop/issues/606) from rivy/dev-up-testing-2
- Merge pull request [#604](https://github.com/ScoopInstaller/Scoop/issues/604) from rivy/dev-up-testing-1
- Merge pull request [#607](https://github.com/ScoopInstaller/Scoop/issues/607) from c33s/patch-1
- Merge pull request [#602](https://github.com/ScoopInstaller/Scoop/issues/602) from berwyn/master
- Merge pull request [#601](https://github.com/ScoopInstaller/Scoop/issues/601) from mattdharmon/patch-1
- Merge pull request [#599](https://github.com/ScoopInstaller/Scoop/issues/599) from Cyianor/master
- Merge pull request [#596](https://github.com/ScoopInstaller/Scoop/issues/596) from moigagoo/patch-18
- Merge pull request [#595](https://github.com/ScoopInstaller/Scoop/issues/595) from sestegra/patch-1
- Merge pull request [#592](https://github.com/ScoopInstaller/Scoop/issues/592) from nightroman/master
- Merge pull request [#590](https://github.com/ScoopInstaller/Scoop/issues/590) from Cyianor/master
- Merge pull request [#588](https://github.com/ScoopInstaller/Scoop/issues/588) from Cyianor/master
- Merge pull request [#586](https://github.com/ScoopInstaller/Scoop/issues/586) from ntwb/nodejs-5-1-1
- Merge pull request [#584](https://github.com/ScoopInstaller/Scoop/issues/584) from belisarh/patch-1
- Merge pull request [#585](https://github.com/ScoopInstaller/Scoop/issues/585) from belisarh/patch-2
- Merge pull request [#581](https://github.com/ScoopInstaller/Scoop/issues/581) from sakai135/patch-13
- Merge pull request [#582](https://github.com/ScoopInstaller/Scoop/issues/582) from sakai135/patch-14
- Merge pull request [#580](https://github.com/ScoopInstaller/Scoop/issues/580) from rodericktech/master
- Merge pull request [#578](https://github.com/ScoopInstaller/Scoop/issues/578) from RobBlackwell/master
- Merge pull request [#577](https://github.com/ScoopInstaller/Scoop/issues/577) from RobBlackwell/master
- Merge pull request [#579](https://github.com/ScoopInstaller/Scoop/issues/579) from andyli/haxe
- Merge pull request [#575](https://github.com/ScoopInstaller/Scoop/issues/575) from nikolasd/patch-1
- Merge pull request [#574](https://github.com/ScoopInstaller/Scoop/issues/574) from Fireforge/patch-1
- Merge pull request [#573](https://github.com/ScoopInstaller/Scoop/issues/573) from sakai135/patch-12
- Merge pull request [#571](https://github.com/ScoopInstaller/Scoop/issues/571) from hansek/update_pshazz
- Merge pull request [#570](https://github.com/ScoopInstaller/Scoop/issues/570) from reelsense/patch-4
- Merge pull request [#569](https://github.com/ScoopInstaller/Scoop/issues/569) from nrakochy/master
- Merge pull request [#568](https://github.com/ScoopInstaller/Scoop/issues/568) from reelsense/patch-3
- Merge pull request [#567](https://github.com/ScoopInstaller/Scoop/issues/567) from milaney/master
- Merge pull request [#566](https://github.com/ScoopInstaller/Scoop/issues/566) from hansek/pshazz_fix
- Merge pull request [#564](https://github.com/ScoopInstaller/Scoop/issues/564) from hansek/pshazz_update
- Merge pull request [#562](https://github.com/ScoopInstaller/Scoop/issues/562) from alapala/master
- Merge pull request [#559](https://github.com/ScoopInstaller/Scoop/issues/559) from nightroman/master
- Merge pull request [#560](https://github.com/ScoopInstaller/Scoop/issues/560) from moigagoo/patch-17
- Merge pull request [#557](https://github.com/ScoopInstaller/Scoop/issues/557) from sakai135/patch-11
- Merge pull request [#556](https://github.com/ScoopInstaller/Scoop/issues/556) from sakai135/patch-10
- Merge pull request [#553](https://github.com/ScoopInstaller/Scoop/issues/553) from sakai135/patch-8
- Merge pull request [#552](https://github.com/ScoopInstaller/Scoop/issues/552) from sakai135/patch-6
- Merge pull request [#554](https://github.com/ScoopInstaller/Scoop/issues/554) from sakai135/patch-7
- Merge pull request [#555](https://github.com/ScoopInstaller/Scoop/issues/555) from sakai135/patch-9
- Merge pull request [#550](https://github.com/ScoopInstaller/Scoop/issues/550) from Stanzilla/patch-1
- Merge pull request [#547](https://github.com/ScoopInstaller/Scoop/issues/547) from belisarh/patch-1
- Merge pull request [#546](https://github.com/ScoopInstaller/Scoop/issues/546) from berwyn/master
- Merge pull request [#544](https://github.com/ScoopInstaller/Scoop/issues/544) from berwyn/master
- Merge pull request [#543](https://github.com/ScoopInstaller/Scoop/issues/543) from petmakris/master
- Merge pull request [#1](https://github.com/ScoopInstaller/Scoop/issues/1) from petmakris/openjdk-checksums
- Merge pull request [#541](https://github.com/ScoopInstaller/Scoop/issues/541) from berwyn/master
- Merge pull request [#540](https://github.com/ScoopInstaller/Scoop/issues/540) from Sandex/master
- Merge pull request [#539](https://github.com/ScoopInstaller/Scoop/issues/539) from devoncarew/master
- Merge pull request [#537](https://github.com/ScoopInstaller/Scoop/issues/537) from danielgrycman/master
- Merge pull request [#534](https://github.com/ScoopInstaller/Scoop/issues/534) from devoncarew/master
- Merge pull request [#535](https://github.com/ScoopInstaller/Scoop/issues/535) from vidarkongsli/master
- Merge pull request [#532](https://github.com/ScoopInstaller/Scoop/issues/532) from danielgrycman/master
- Merge pull request [#531](https://github.com/ScoopInstaller/Scoop/issues/531) from mathieucarbou/patch-1
- Merge pull request [#527](https://github.com/ScoopInstaller/Scoop/issues/527) from sakai135/patch-5
- Merge pull request [#526](https://github.com/ScoopInstaller/Scoop/issues/526) from iakio/master
- Merge pull request [#525](https://github.com/ScoopInstaller/Scoop/issues/525) from berwyn/master
- Merge pull request [#524](https://github.com/ScoopInstaller/Scoop/issues/524) from danielgrycman/master
- Merge pull request [#522](https://github.com/ScoopInstaller/Scoop/issues/522) from danielgrycman/master
- Merge pull request [#521](https://github.com/ScoopInstaller/Scoop/issues/521) from EmberQuill/master
- Merge pull request [#520](https://github.com/ScoopInstaller/Scoop/issues/520) from danielgrycman/master
- Merge pull request [#519](https://github.com/ScoopInstaller/Scoop/issues/519) from distkloc/specify-gibo-version
- Merge pull request [#518](https://github.com/ScoopInstaller/Scoop/issues/518) from reelsense/patch-1
- Merge pull request [#516](https://github.com/ScoopInstaller/Scoop/issues/516) from sakai135/patch-4
- Merge pull request [#515](https://github.com/ScoopInstaller/Scoop/issues/515) from belisarh/patch-1
- Merge pull request [#514](https://github.com/ScoopInstaller/Scoop/issues/514) from belisarh/patch-1
- Merge pull request [#512](https://github.com/ScoopInstaller/Scoop/issues/512) from bcomnes/patch-1
- Merge pull request [#510](https://github.com/ScoopInstaller/Scoop/issues/510) from sakai135/patch-3
- Merge pull request [#508](https://github.com/ScoopInstaller/Scoop/issues/508) from moigagoo/patch-15
- Merge pull request [#509](https://github.com/ScoopInstaller/Scoop/issues/509) from moigagoo/patch-16
- Merge pull request [#503](https://github.com/ScoopInstaller/Scoop/issues/503) from sakai135/patch-2
- Merge pull request [#502](https://github.com/ScoopInstaller/Scoop/issues/502) from sakai135/patch-1
- Merge pull request [#500](https://github.com/ScoopInstaller/Scoop/issues/500) from seonho/patch-2
- Merge pull request [#498](https://github.com/ScoopInstaller/Scoop/issues/498) from moigagoo/patch-14
- Merge pull request [#499](https://github.com/ScoopInstaller/Scoop/issues/499) from belisarh/patch-1
- Merge pull request [#497](https://github.com/ScoopInstaller/Scoop/issues/497) from sakai135/patch-7
- Merge pull request [#496](https://github.com/ScoopInstaller/Scoop/issues/496) from sakai135/patch-6
- Merge pull request [#495](https://github.com/ScoopInstaller/Scoop/issues/495) from sakai135/patch-5
- Merge pull request [#494](https://github.com/ScoopInstaller/Scoop/issues/494) from sakai135/patch-4
- Merge pull request [#493](https://github.com/ScoopInstaller/Scoop/issues/493) from sakai135/patch-3
- Merge pull request [#492](https://github.com/ScoopInstaller/Scoop/issues/492) from alapala/master
- Merge pull request [#489](https://github.com/ScoopInstaller/Scoop/issues/489) from Nunnery/patch-1
- Merge pull request [#490](https://github.com/ScoopInstaller/Scoop/issues/490) from seonho/patch-1
- Merge pull request [#487](https://github.com/ScoopInstaller/Scoop/issues/487) from guillermooo-forks/master
- Merge pull request [#477](https://github.com/ScoopInstaller/Scoop/issues/477) from rivy/fix-tests-core-Win10
- Merge pull request [#462](https://github.com/ScoopInstaller/Scoop/issues/462) from rivy/dev-whitespace
- Merge pull request [#482](https://github.com/ScoopInstaller/Scoop/issues/482) from rivy/add-app-pcre
- Merge pull request [#479](https://github.com/ScoopInstaller/Scoop/issues/479) from rivy/add-tests-syntax
- Merge pull request [#475](https://github.com/ScoopInstaller/Scoop/issues/475) from rivy/fix-tests
- Merge pull request [#473](https://github.com/ScoopInstaller/Scoop/issues/473) from masonm12/premake5
- Merge pull request [#472](https://github.com/ScoopInstaller/Scoop/issues/472) from reyerstudio/go
- Merge pull request [#468](https://github.com/ScoopInstaller/Scoop/issues/468) from barohatoum/patch-1
- Merge pull request [#469](https://github.com/ScoopInstaller/Scoop/issues/469) from iakio/master
- Merge pull request [#470](https://github.com/ScoopInstaller/Scoop/issues/470) from devoncarew/master
- Merge pull request [#437](https://github.com/ScoopInstaller/Scoop/issues/437) from rivy/fix-shim-encoding
- Merge pull request [#467](https://github.com/ScoopInstaller/Scoop/issues/467) from moigagoo/patch-13
- Merge pull request [#466](https://github.com/ScoopInstaller/Scoop/issues/466) from ntwb/patch-5
- Merge pull request [#464](https://github.com/ScoopInstaller/Scoop/issues/464) from ntwb/patch-2
- Merge pull request [#465](https://github.com/ScoopInstaller/Scoop/issues/465) from ntwb/patch-4
- Merge pull request [#463](https://github.com/ScoopInstaller/Scoop/issues/463) from ntwb/patch-1
- Merge pull request [#457](https://github.com/ScoopInstaller/Scoop/issues/457) from sakai135/patch-2
- Merge pull request [#456](https://github.com/ScoopInstaller/Scoop/issues/456) from sakai135/patch-1
- Merge pull request [#455](https://github.com/ScoopInstaller/Scoop/issues/455) from NilsNojje/master
- Merge pull request [#453](https://github.com/ScoopInstaller/Scoop/issues/453) from huncrys/patch-4
- Merge pull request [#452](https://github.com/ScoopInstaller/Scoop/issues/452) from shustariov-andrey/master
- Merge pull request [#450](https://github.com/ScoopInstaller/Scoop/issues/450) from moigagoo/patch-12
- Merge pull request [#449](https://github.com/ScoopInstaller/Scoop/issues/449) from moigagoo/patch-11
- Merge pull request [#446](https://github.com/ScoopInstaller/Scoop/issues/446) from shustariov-andrey/master
- Merge pull request [#443](https://github.com/ScoopInstaller/Scoop/issues/443) from lukesampson/shim-relative
- Merge pull request [#440](https://github.com/ScoopInstaller/Scoop/issues/440) from Madsn/patch-2
- Merge pull request [#441](https://github.com/ScoopInstaller/Scoop/issues/441) from Madsn/patch-3
- Merge pull request [#439](https://github.com/ScoopInstaller/Scoop/issues/439) from Madsn/patch-1
- Merge pull request [#434](https://github.com/ScoopInstaller/Scoop/issues/434) from rivy/fix-appveyor
- Merge pull request [#438](https://github.com/ScoopInstaller/Scoop/issues/438) from rivy/dev-editorconfig
- Merge pull request [#436](https://github.com/ScoopInstaller/Scoop/issues/436) from lukesampson/issue-386
- Merge pull request [#435](https://github.com/ScoopInstaller/Scoop/issues/435) from dagezi/ctags
- Merge pull request [#432](https://github.com/ScoopInstaller/Scoop/issues/432) from sakai135/patch-19
- Merge pull request [#431](https://github.com/ScoopInstaller/Scoop/issues/431) from iakio/remove-checkver
- Merge pull request [#430](https://github.com/ScoopInstaller/Scoop/issues/430) from iakio/vagrant
- Merge pull request [#429](https://github.com/ScoopInstaller/Scoop/issues/429) from iakio/vagrant-regexp-fix
- Merge pull request [#426](https://github.com/ScoopInstaller/Scoop/issues/426) from devoncarew/1.11.1
- Merge pull request [#425](https://github.com/ScoopInstaller/Scoop/issues/425) from sakai135/patch-18
- Merge pull request [#423](https://github.com/ScoopInstaller/Scoop/issues/423) from jamesmstone/patch-1
- Merge pull request [#422](https://github.com/ScoopInstaller/Scoop/issues/422) from jamesmstone/patch-4
- Merge pull request [#421](https://github.com/ScoopInstaller/Scoop/issues/421) from jamesmstone/patch-3
- Merge pull request [#420](https://github.com/ScoopInstaller/Scoop/issues/420) from jamesmstone/patch-2
- Merge pull request [#419](https://github.com/ScoopInstaller/Scoop/issues/419) from sakai135/patch-17
- Merge pull request [#418](https://github.com/ScoopInstaller/Scoop/issues/418) from iakio/php_5.6.11
- Merge pull request [#417](https://github.com/ScoopInstaller/Scoop/issues/417) from masonm12/premake5
- Merge pull request [#415](https://github.com/ScoopInstaller/Scoop/issues/415) from sakai135/patch-16
- Merge pull request [#414](https://github.com/ScoopInstaller/Scoop/issues/414) from nishanthkarthik/patch-1
- Merge pull request [#413](https://github.com/ScoopInstaller/Scoop/issues/413) from nightroman/master
- Merge pull request [#412](https://github.com/ScoopInstaller/Scoop/issues/412) from sakai135/patch-15
- Merge pull request [#411](https://github.com/ScoopInstaller/Scoop/issues/411) from rivy/fix-gow
- Merge pull request [#407](https://github.com/ScoopInstaller/Scoop/issues/407) from dennislloydjr/gradle_2_4
- Merge pull request [#406](https://github.com/ScoopInstaller/Scoop/issues/406) from paq/update-node-0-12-5
- Merge pull request [#403](https://github.com/ScoopInstaller/Scoop/issues/403) from guillermooo-forks/update-dart-1-11-0
- Merge pull request [#402](https://github.com/ScoopInstaller/Scoop/issues/402) from rivy/fix-perl
- Merge pull request [#401](https://github.com/ScoopInstaller/Scoop/issues/401) from sakai135/patch-14
- Merge pull request [#400](https://github.com/ScoopInstaller/Scoop/issues/400) from sakai135/patch-13
- Merge pull request [#399](https://github.com/ScoopInstaller/Scoop/issues/399) from paq/update-haxe
- Merge pull request [#398](https://github.com/ScoopInstaller/Scoop/issues/398) from guillermooo-forks/update-rust
- Merge pull request [#396](https://github.com/ScoopInstaller/Scoop/issues/396) from chidea/patch-1
- Merge pull request [#393](https://github.com/ScoopInstaller/Scoop/issues/393) from nilkesede/master
- Merge pull request [#390](https://github.com/ScoopInstaller/Scoop/issues/390) from ntwb/openssl-1.0.2b
- Merge pull request [#388](https://github.com/ScoopInstaller/Scoop/issues/388) from sakai135/patch-12
- Merge pull request [#384](https://github.com/ScoopInstaller/Scoop/issues/384) from lukesampson/update-quiet
- Merge pull request [#383](https://github.com/ScoopInstaller/Scoop/issues/383) from reyerstudio/hugo
- Merge pull request [#380](https://github.com/ScoopInstaller/Scoop/issues/380) from lukesampson/scoop-alias
- Merge pull request [#379](https://github.com/ScoopInstaller/Scoop/issues/379) from lukesampson/shim-robocopy
- Merge pull request [#381](https://github.com/ScoopInstaller/Scoop/issues/381) from azabujuban/master
- Merge pull request [#360](https://github.com/ScoopInstaller/Scoop/issues/360) from lukesampson/aliases
- Merge pull request [#372](https://github.com/ScoopInstaller/Scoop/issues/372) from guillermooo-forks/refactor-dart-manifest
- Merge pull request [#370](https://github.com/ScoopInstaller/Scoop/issues/370) from azabujuban/master
- Merge pull request [#369](https://github.com/ScoopInstaller/Scoop/issues/369) from masonm12/premake5
- Merge pull request [#368](https://github.com/ScoopInstaller/Scoop/issues/368) from moigagoo/patch-9
- Merge pull request [#367](https://github.com/ScoopInstaller/Scoop/issues/367) from sakai135/patch-11
- Merge pull request [#366](https://github.com/ScoopInstaller/Scoop/issues/366) from sakai135/patch-10
- Merge pull request [#363](https://github.com/ScoopInstaller/Scoop/issues/363) from moigagoo/patch-8
- Merge pull request [#362](https://github.com/ScoopInstaller/Scoop/issues/362) from moigagoo/patch-7
- Merge pull request [#361](https://github.com/ScoopInstaller/Scoop/issues/361) from sestegra/master
- Merge pull request [#357](https://github.com/ScoopInstaller/Scoop/issues/357) from lukesampson/revert-355-feature/scoop-reset-scoop
- Merge pull request [#355](https://github.com/ScoopInstaller/Scoop/issues/355) from lukesampson/feature/scoop-reset-scoop
- Merge pull request [#356](https://github.com/ScoopInstaller/Scoop/issues/356) from moigagoo/patch-6
- Merge pull request [#352](https://github.com/ScoopInstaller/Scoop/issues/352) from sakai135/patch-8
- Merge pull request [#353](https://github.com/ScoopInstaller/Scoop/issues/353) from sakai135/patch-9
- Merge pull request [#348](https://github.com/ScoopInstaller/Scoop/issues/348) from nightroman/master
- Merge pull request [#347](https://github.com/ScoopInstaller/Scoop/issues/347) from TylerHaigh/scholdoc
- Merge pull request [#346](https://github.com/ScoopInstaller/Scoop/issues/346) from nightroman/master
- Merge pull request [#345](https://github.com/ScoopInstaller/Scoop/issues/345) from iakio/php-update
- Merge pull request [#344](https://github.com/ScoopInstaller/Scoop/issues/344) from jlchoike/feature/add_grails
- Merge pull request [#343](https://github.com/ScoopInstaller/Scoop/issues/343) from jlchoike/feature/update_groovy_243
- Merge pull request [#341](https://github.com/ScoopInstaller/Scoop/issues/341) from gutierri/master
- Merge pull request [#338](https://github.com/ScoopInstaller/Scoop/issues/338) from lukesampson/shimtests
- Merge pull request [#337](https://github.com/ScoopInstaller/Scoop/issues/337) from lukesampson/manifest-validation
- Merge pull request [#336](https://github.com/ScoopInstaller/Scoop/issues/336) from lukesampson/pester-tests
- Merge pull request [#333](https://github.com/ScoopInstaller/Scoop/issues/333) from scottwillmoore/add-premake
- Merge pull request [#334](https://github.com/ScoopInstaller/Scoop/issues/334) from scottwillmoore/add-ninja
- Merge pull request [#332](https://github.com/ScoopInstaller/Scoop/issues/332) from scottwillmoore/add-hub
- Merge pull request [#331](https://github.com/ScoopInstaller/Scoop/issues/331) from lukesampson/appveyor-ci
- Merge pull request [#329](https://github.com/ScoopInstaller/Scoop/issues/329) from guillermooo-forks/fix-vim-shell-option
- Merge pull request [#327](https://github.com/ScoopInstaller/Scoop/issues/327) from guillermooo-forks/fix-vim-shell-option
- Merge pull request [#323](https://github.com/ScoopInstaller/Scoop/issues/323) from gutierri/master
- Merge pull request [#320](https://github.com/ScoopInstaller/Scoop/issues/320) from deevus/scoop-update-git
- Merge pull request [#321](https://github.com/ScoopInstaller/Scoop/issues/321) from ntwb/ruby221
- Merge pull request [#316](https://github.com/ScoopInstaller/Scoop/issues/316) from teadawg/patch-1
- Merge pull request [#318](https://github.com/ScoopInstaller/Scoop/issues/318) from rmyorston/master
- Merge pull request [#317](https://github.com/ScoopInstaller/Scoop/issues/317) from moigagoo/patch-5
- Merge pull request [#314](https://github.com/ScoopInstaller/Scoop/issues/314) from lukesampson/nightly-support
- Merge pull request [#313](https://github.com/ScoopInstaller/Scoop/issues/313) from huncrys/patch-3
- Merge pull request [#311](https://github.com/ScoopInstaller/Scoop/issues/311) from huncrys/patch-1
- Merge pull request [#312](https://github.com/ScoopInstaller/Scoop/issues/312) from huncrys/patch-2
- Merge pull request [#309](https://github.com/ScoopInstaller/Scoop/issues/309) from lukesampson/scoop-home
- Merge pull request [#308](https://github.com/ScoopInstaller/Scoop/issues/308) from lukesampson/update-no-cache
- Merge pull request [#307](https://github.com/ScoopInstaller/Scoop/issues/307) from lukesampson/custom-commands
- Merge pull request [#306](https://github.com/ScoopInstaller/Scoop/issues/306) from lukesampson/revert-305-custom-commands
- Merge pull request [#305](https://github.com/ScoopInstaller/Scoop/issues/305) from lukesampson/custom-commands
- Merge pull request [#299](https://github.com/ScoopInstaller/Scoop/issues/299) from sakai135/patch-3
- Merge pull request [#297](https://github.com/ScoopInstaller/Scoop/issues/297) from sakai135/patch-1
- Merge pull request [#298](https://github.com/ScoopInstaller/Scoop/issues/298) from sakai135/patch-2
- Merge pull request [#300](https://github.com/ScoopInstaller/Scoop/issues/300) from sakai135/patch-4
- Merge pull request [#301](https://github.com/ScoopInstaller/Scoop/issues/301) from sakai135/patch-5
- Merge pull request [#302](https://github.com/ScoopInstaller/Scoop/issues/302) from sakai135/patch-6
- Merge pull request [#293](https://github.com/ScoopInstaller/Scoop/issues/293) from lukesampson/aspnet-vnext
- Merge pull request [#292](https://github.com/ScoopInstaller/Scoop/issues/292) from deevus/bfg-1.12.3
- Merge pull request [#291](https://github.com/ScoopInstaller/Scoop/issues/291) from deevus/scoop-create
- Merge pull request [#290](https://github.com/ScoopInstaller/Scoop/issues/290) from deevus/scoop-create
- Merge pull request [#287](https://github.com/ScoopInstaller/Scoop/issues/287) from sakai135/patch-2
- Merge pull request [#288](https://github.com/ScoopInstaller/Scoop/issues/288) from sakai135/patch-3
- Merge pull request [#286](https://github.com/ScoopInstaller/Scoop/issues/286) from sakai135/patch-1
- Merge pull request [#284](https://github.com/ScoopInstaller/Scoop/issues/284) from Silanus/patch-1
- Merge pull request [#279](https://github.com/ScoopInstaller/Scoop/issues/279) from luiscoms/bucket_update
- Merge pull request [#277](https://github.com/ScoopInstaller/Scoop/issues/277) from myty/dev
- Merge pull request [#276](https://github.com/ScoopInstaller/Scoop/issues/276) from sakai135/patch-1
- Merge pull request [#275](https://github.com/ScoopInstaller/Scoop/issues/275) from vidarkongsli/patch-2
- Merge pull request [#273](https://github.com/ScoopInstaller/Scoop/issues/273) from luiscoms/bucket_php
- Merge pull request [#272](https://github.com/ScoopInstaller/Scoop/issues/272) from myty/dev
- Merge pull request [#271](https://github.com/ScoopInstaller/Scoop/issues/271) from vidarkongsli/patch-1
- Merge pull request [#270](https://github.com/ScoopInstaller/Scoop/issues/270) from myty/dev
- Merge pull request [#269](https://github.com/ScoopInstaller/Scoop/issues/269) from jlchoike/feature/gradle-upgrade-2.2.1
- Merge pull request [#268](https://github.com/ScoopInstaller/Scoop/issues/268) from jlchoike/feature/groovy-upgrade-2.4.0
- Merge pull request [#266](https://github.com/ScoopInstaller/Scoop/issues/266) from myty/feature-update-scriptcs
- Merge pull request [#265](https://github.com/ScoopInstaller/Scoop/issues/265) from myty/feature-update-scriptcs
- Merge pull request [#264](https://github.com/ScoopInstaller/Scoop/issues/264) from kyungminlee/master
- Merge pull request [#263](https://github.com/ScoopInstaller/Scoop/issues/263) from scottwillmoore/update-nimrod
- Merge pull request [#262](https://github.com/ScoopInstaller/Scoop/issues/262) from kyungminlee/master
- Merge pull request [#259](https://github.com/ScoopInstaller/Scoop/issues/259) from 2Toad/master
- Merge pull request [#258](https://github.com/ScoopInstaller/Scoop/issues/258) from sakai135/patch-4
- Merge pull request [#257](https://github.com/ScoopInstaller/Scoop/issues/257) from 2Toad/master
- Merge pull request [#256](https://github.com/ScoopInstaller/Scoop/issues/256) from josephst/patch-1
- Merge pull request [#255](https://github.com/ScoopInstaller/Scoop/issues/255) from sakai135/patch-2
- Merge pull request [#253](https://github.com/ScoopInstaller/Scoop/issues/253) from sakai135/patch-1
- Merge pull request [#250](https://github.com/ScoopInstaller/Scoop/issues/250) from myty/patch-3
- Merge pull request [#247](https://github.com/ScoopInstaller/Scoop/issues/247) from scottwillmoore/rename-maven
- Merge pull request [#245](https://github.com/ScoopInstaller/Scoop/issues/245) from myty/patch-2
- Merge pull request [#244](https://github.com/ScoopInstaller/Scoop/issues/244) from jkrehm/fix-apache-hash
- Merge pull request [#242](https://github.com/ScoopInstaller/Scoop/issues/242) from sestegra/update_golang
- Merge pull request [#243](https://github.com/ScoopInstaller/Scoop/issues/243) from jkrehm/update-php
- Merge pull request [#240](https://github.com/ScoopInstaller/Scoop/issues/240) from myty/patch-1
- Merge pull request [#239](https://github.com/ScoopInstaller/Scoop/issues/239) from ntwb/patch-18
- Merge pull request [#238](https://github.com/ScoopInstaller/Scoop/issues/238) from myty/patch-1
- Merge pull request [#234](https://github.com/ScoopInstaller/Scoop/issues/234) from gutierri/master
- Merge pull request [#232](https://github.com/ScoopInstaller/Scoop/issues/232) from myty/master
- Merge pull request [#231](https://github.com/ScoopInstaller/Scoop/issues/231) from Silanus/patch-1
- Merge pull request [#228](https://github.com/ScoopInstaller/Scoop/issues/228) from RobBlackwell/master
- Merge pull request [#227](https://github.com/ScoopInstaller/Scoop/issues/227) from ntwb/patch-17
- Merge pull request [#226](https://github.com/ScoopInstaller/Scoop/issues/226) from ntwb/patch-16
- Merge pull request [#224](https://github.com/ScoopInstaller/Scoop/issues/224) from ntwb/patch-14
- Merge pull request [#225](https://github.com/ScoopInstaller/Scoop/issues/225) from ntwb/patch-15
- Merge pull request [#223](https://github.com/ScoopInstaller/Scoop/issues/223) from ntwb/patch-13
- Merge pull request [#221](https://github.com/ScoopInstaller/Scoop/issues/221) from jkrehm/update-php
- Merge pull request [#222](https://github.com/ScoopInstaller/Scoop/issues/222) from jkrehm/update-nodejs
- Merge pull request [#219](https://github.com/ScoopInstaller/Scoop/issues/219) from kyungminlee/master
- Merge pull request [#218](https://github.com/ScoopInstaller/Scoop/issues/218) from kyungminlee/master
- Merge pull request [#217](https://github.com/ScoopInstaller/Scoop/issues/217) from ntwb/patch-12
- Merge pull request [#215](https://github.com/ScoopInstaller/Scoop/issues/215) from RobBlackwell/master
- Merge pull request [#213](https://github.com/ScoopInstaller/Scoop/issues/213) from myty/patch-1
- Merge pull request [#209](https://github.com/ScoopInstaller/Scoop/issues/209) from shipcod3/master
- Merge pull request [#208](https://github.com/ScoopInstaller/Scoop/issues/208) from shipcod3/master
- Merge pull request [#207](https://github.com/ScoopInstaller/Scoop/issues/207) from lukesampson/revert-206-master
- Merge pull request [#206](https://github.com/ScoopInstaller/Scoop/issues/206) from shipcod3/master
- Merge pull request [#205](https://github.com/ScoopInstaller/Scoop/issues/205) from scottwillmoore/fix-kotlin
- Merge pull request [#204](https://github.com/ScoopInstaller/Scoop/issues/204) from scottwillmoore/add-nimrod
- Merge pull request [#200](https://github.com/ScoopInstaller/Scoop/issues/200) from scottwillmoore/update-haxe
- Merge pull request [#201](https://github.com/ScoopInstaller/Scoop/issues/201) from scottwillmoore/depends-openjdk
- Merge pull request [#198](https://github.com/ScoopInstaller/Scoop/issues/198) from scottwillmoore/update-openjdk
- Merge pull request [#199](https://github.com/ScoopInstaller/Scoop/issues/199) from scottwillmoore/add-jvm-languages
- Merge pull request [#197](https://github.com/ScoopInstaller/Scoop/issues/197) from ntwb/master
- Merge pull request [#195](https://github.com/ScoopInstaller/Scoop/issues/195) from vidarkongsli/patch-1
- Merge pull request [#191](https://github.com/ScoopInstaller/Scoop/issues/191) from scottwillmoore/add-ant
- Merge pull request [#188](https://github.com/ScoopInstaller/Scoop/issues/188) from scottwillmoore/add-haxe
- Merge pull request [#187](https://github.com/ScoopInstaller/Scoop/issues/187) from deevus/vim
- Merge pull request [#186](https://github.com/ScoopInstaller/Scoop/issues/186) from kodybrown/master
- Merge pull request [#185](https://github.com/ScoopInstaller/Scoop/issues/185) from Silanus/master
- Merge pull request [#184](https://github.com/ScoopInstaller/Scoop/issues/184) from jkrehm/update-php
- Merge pull request [#182](https://github.com/ScoopInstaller/Scoop/issues/182) from deevus/mariadb
- Merge pull request [#180](https://github.com/ScoopInstaller/Scoop/issues/180) from deevus/master
- Merge pull request [#179](https://github.com/ScoopInstaller/Scoop/issues/179) from dre1080/patch-1
- Merge pull request [#178](https://github.com/ScoopInstaller/Scoop/issues/178) from jkrehm/fix-php-hash
- Merge pull request [#175](https://github.com/ScoopInstaller/Scoop/issues/175) from sakai135/patch-3
- Merge pull request [#174](https://github.com/ScoopInstaller/Scoop/issues/174) from myty/patch-1
- Merge pull request [#173](https://github.com/ScoopInstaller/Scoop/issues/173) from ntwb/patch-10
- Merge pull request [#172](https://github.com/ScoopInstaller/Scoop/issues/172) from ntwb/patch-9
- Merge pull request [#171](https://github.com/ScoopInstaller/Scoop/issues/171) from ntwb/patch-8
- Merge pull request [#170](https://github.com/ScoopInstaller/Scoop/issues/170) from ntwb/patch-7
- Merge pull request [#169](https://github.com/ScoopInstaller/Scoop/issues/169) from ntwb/patch-6
- Merge pull request [#168](https://github.com/ScoopInstaller/Scoop/issues/168) from ntwb/patch-5
- Merge pull request [#167](https://github.com/ScoopInstaller/Scoop/issues/167) from ntwb/patch-4
- Merge pull request [#166](https://github.com/ScoopInstaller/Scoop/issues/166) from ntwb/patch-3
- Merge pull request [#165](https://github.com/ScoopInstaller/Scoop/issues/165) from ntwb/patch-2
- Merge pull request [#164](https://github.com/ScoopInstaller/Scoop/issues/164) from ntwb/patch-1
- Merge pull request [#158](https://github.com/ScoopInstaller/Scoop/issues/158) from jkrehm/nodejs-0.10.31
- Merge pull request [#159](https://github.com/ScoopInstaller/Scoop/issues/159) from jkrehm/php-checkver
- Merge pull request [#157](https://github.com/ScoopInstaller/Scoop/issues/157) from sakai135/patch-2
- Merge pull request [#156](https://github.com/ScoopInstaller/Scoop/issues/156) from sakai135/patch-1
- Merge pull request [#154](https://github.com/ScoopInstaller/Scoop/issues/154) from jkrehm/php56
- Merge pull request [#153](https://github.com/ScoopInstaller/Scoop/issues/153) from jkrehm/update-php
- Merge pull request [#152](https://github.com/ScoopInstaller/Scoop/issues/152) from dennislloydjr/openssl_1_0_1i
- Merge pull request [#150](https://github.com/ScoopInstaller/Scoop/issues/150) from kodybrown/master
- Merge pull request [#149](https://github.com/ScoopInstaller/Scoop/issues/149) from ntwb/master
- Merge pull request [#148](https://github.com/ScoopInstaller/Scoop/issues/148) from kodybrown/master
- Merge pull request [#147](https://github.com/ScoopInstaller/Scoop/issues/147) from kodybrown/master
- Merge pull request [#145](https://github.com/ScoopInstaller/Scoop/issues/145) from moigagoo/patch-4
- Merge pull request [#144](https://github.com/ScoopInstaller/Scoop/issues/144) from LordZepto/patch-1
- Merge pull request [#143](https://github.com/ScoopInstaller/Scoop/issues/143) from pablocrivella/patch-5
- Merge pull request [#142](https://github.com/ScoopInstaller/Scoop/issues/142) from pablocrivella/patch-4
- Merge pull request [#140](https://github.com/ScoopInstaller/Scoop/issues/140) from pablocrivella/patch-2
- Merge pull request [#141](https://github.com/ScoopInstaller/Scoop/issues/141) from pablocrivella/patch-3
- Merge pull request [#138](https://github.com/ScoopInstaller/Scoop/issues/138) from pablocrivella/patch-1
- Merge pull request [#134](https://github.com/ScoopInstaller/Scoop/issues/134) from sakai135/patch-3
- Merge pull request [#132](https://github.com/ScoopInstaller/Scoop/issues/132) from moigagoo/patch-3
- Merge pull request [#131](https://github.com/ScoopInstaller/Scoop/issues/131) from sakai135/patch-1
- Merge pull request [#133](https://github.com/ScoopInstaller/Scoop/issues/133) from sakai135/patch-2
- Merge pull request [#124](https://github.com/ScoopInstaller/Scoop/issues/124) from moigagoo/patch-2
- Merge pull request [#123](https://github.com/ScoopInstaller/Scoop/issues/123) from manuclementz/patch-1
- Merge pull request [#121](https://github.com/ScoopInstaller/Scoop/issues/121) from sakai135/patch-1
- Merge pull request [#120](https://github.com/ScoopInstaller/Scoop/issues/120) from tonidy/master
- Merge pull request [#119](https://github.com/ScoopInstaller/Scoop/issues/119) from moigagoo/patch-1
- Merge pull request [#117](https://github.com/ScoopInstaller/Scoop/issues/117) from moigagoo/patch-3
- Merge pull request [#116](https://github.com/ScoopInstaller/Scoop/issues/116) from moigagoo/patch-1
- Merge pull request [#115](https://github.com/ScoopInstaller/Scoop/issues/115) from sakai135/patch-4
- Merge pull request [#113](https://github.com/ScoopInstaller/Scoop/issues/113) from sakai135/patch-3
- Merge pull request [#112](https://github.com/ScoopInstaller/Scoop/issues/112) from sakai135/patch-2
- Merge pull request [#106](https://github.com/ScoopInstaller/Scoop/issues/106) from sakai135/patch-1
- Merge pull request [#102](https://github.com/ScoopInstaller/Scoop/issues/102) from sakai135/patch-4
- Merge pull request [#101](https://github.com/ScoopInstaller/Scoop/issues/101) from sakai135/checkver-for-mongodb
- Merge pull request [#100](https://github.com/ScoopInstaller/Scoop/issues/100) from sakai135/patch-3
- Merge pull request [#99](https://github.com/ScoopInstaller/Scoop/issues/99) from sakai135/patch-2
- Merge pull request [#98](https://github.com/ScoopInstaller/Scoop/issues/98) from sakai135/patch-1
- Merge pull request [#93](https://github.com/ScoopInstaller/Scoop/issues/93) from sakai135/patch-1
- Merge pull request [#94](https://github.com/ScoopInstaller/Scoop/issues/94) from sakai135/patch-2
- Merge pull request [#92](https://github.com/ScoopInstaller/Scoop/issues/92) from sakai135/patch-1
- Merge pull request [#91](https://github.com/ScoopInstaller/Scoop/issues/91) from sakai135/patch-1
- Merge pull request [#90](https://github.com/ScoopInstaller/Scoop/issues/90) from ntwb/patch-2
- Merge pull request [#89](https://github.com/ScoopInstaller/Scoop/issues/89) from ntwb/patch-1
- Merge pull request [#82](https://github.com/ScoopInstaller/Scoop/issues/82) from ntwb/master
- Merge pull request [#81](https://github.com/ScoopInstaller/Scoop/issues/81) from moigagoo/master
- Merge pull request [#78](https://github.com/ScoopInstaller/Scoop/issues/78) from moigagoo/patch-2
- Merge pull request [#79](https://github.com/ScoopInstaller/Scoop/issues/79) from moigagoo/patch-3
- Merge pull request [#77](https://github.com/ScoopInstaller/Scoop/issues/77) from ntwb/master
- Merge pull request [#75](https://github.com/ScoopInstaller/Scoop/issues/75) from ntwb/master
- Merge pull request [#74](https://github.com/ScoopInstaller/Scoop/issues/74) from ntwb/master
- Merge pull request [#73](https://github.com/ScoopInstaller/Scoop/issues/73) from moigagoo/patch-1
- Merge pull request [#72](https://github.com/ScoopInstaller/Scoop/issues/72) from ntwb/master
- Merge pull request [#71](https://github.com/ScoopInstaller/Scoop/issues/71) from jkrehm/update-php
- Merge pull request [#69](https://github.com/ScoopInstaller/Scoop/issues/69) from richorama/master
- Merge pull request [#68](https://github.com/ScoopInstaller/Scoop/issues/68) from richorama/master
- Merge pull request [#67](https://github.com/ScoopInstaller/Scoop/issues/67) from ntwb/master
- Merge pull request [#65](https://github.com/ScoopInstaller/Scoop/issues/65) from beppler/scriptcs
- Merge pull request [#64](https://github.com/ScoopInstaller/Scoop/issues/64) from beppler/scriptcs-0.9
- Merge pull request [#63](https://github.com/ScoopInstaller/Scoop/issues/63) from alebelcor/add-iconv
- Merge pull request [#62](https://github.com/ScoopInstaller/Scoop/issues/62) from jkrehm/update-php
- Merge pull request [#61](https://github.com/ScoopInstaller/Scoop/issues/61) from nanttylove/master
- Merge pull request [#57](https://github.com/ScoopInstaller/Scoop/issues/57) from jkrehm/php5.5.8
- Merge pull request [#58](https://github.com/ScoopInstaller/Scoop/issues/58) from jkrehm/php5.4.24
- Merge pull request [#53](https://github.com/ScoopInstaller/Scoop/issues/53) from jkrehm/php54
- Merge pull request [#54](https://github.com/ScoopInstaller/Scoop/issues/54) from jkrehm/php53
- Merge pull request [#51](https://github.com/ScoopInstaller/Scoop/issues/51) from amatashkin/createdir
- Merge pull request [#49](https://github.com/ScoopInstaller/Scoop/issues/49) from jkrehm/update-php
- Merge pull request [#47](https://github.com/ScoopInstaller/Scoop/issues/47) from bleepbloop/whois
- Merge pull request [#43](https://github.com/ScoopInstaller/Scoop/issues/43) from bleepbloop/setuptools
- Merge pull request [#40](https://github.com/ScoopInstaller/Scoop/issues/40) from andreabergia/maven
- Merge pull request [#39](https://github.com/ScoopInstaller/Scoop/issues/39) from andreabergia/sbt
- Merge pull request [#38](https://github.com/ScoopInstaller/Scoop/issues/38) from richorama/master
- Merge pull request [#32](https://github.com/ScoopInstaller/Scoop/issues/32) from ntwb/patch-1
- Merge pull request [#28](https://github.com/ScoopInstaller/Scoop/issues/28) from richorama/master
