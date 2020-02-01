# Contributing

There are two main ways how to contribute to the Scoop codebase.

1. [Extending codebase of scoop itself](#core-codebase)
1. [Writing/updating manifests](#manifest-creation)

If you have a question regarding Scoop overall, feel free to head into the community Discord server. (Invitation link inside [README][README])

## Core codebase

You can contribute to core codebase these ways:

1. [Implement new features](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Aenhancement)
1. [Fix bugs](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Abug)
1. Identify and report reproducible steps of issues

Scoop's core codebase started moving towards standard/preferred PowerShell code style.
Mainly with the adoption of [`Verb-Noun`][approved-verbs] naming.
Starting from April 2019, use `Verb-Noun` naming for functions when manipulating the codebase.

### How to properly deprecate a function

When you want to refactor any function, keep in mind that the original function needs to remain with the same name, parameters, return values. Hence, tools that are utilizing scoop's core codebase have time to adapt to new changes without breaking functionality.
Some internal functions are used inside manifests, and if they would be removed, all these manifests cannot be installed.

1. Create the new function with `Verb-Noun` name
    1. Use [`[CmdletBinding()]`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-6)
        - With binding functions benefit from advantages of compiled cmdlets
            - Default parameters are added (Debug, Verbose, ErrorAction, ...)
1. Change the body of the old function to this:

```powershell
function old_f {
    Show-DeprecatedWarning $MyInvocation 'New-FunctionName'
    New-FunctionName -SomeParametersYouNeedToAchieveSameBehaviour
}
```

See [Decompress module](https://github.com/lukesampson/scoop/blob/1caaed8f3d51d141c6cafe7dc690b7dc08802702/lib/decompress.ps1) for specific example.

### General code sins to avoid and restrictions to follow

Few misdemeanors often show up in pull-requests and codebase.
Keep source code tidier and cleaner with following best practices.

- Commits/pull-requests naming have to follow [Conventional Commits Specification][commits]
- [Cmdlet aliases](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/AvoidUsingCmdletAliases.md) usage
    - Never use aliases
    - Aliases are useful only in interactive (terminal) usage
    - Code readability is significantly lowered
    - Also, aliases could be different in different workspaces/system versions
- Short format of function parameters
    - Powershell allows you to use a short version of parameters
        - Instead of `Write-Host -ForegroundColor Yellow` you can use `Write-Host -f Yellow`
        - This should be avoided due to compatibility with newer versions of PowerShell / functions
    - When there are parameters with the same starting characters, it leads to `Ambiguous` parameter error (`gci -p` for example)
- Do not return data from a function without `return` statement
    - Powershell allow to "return" data from function with simply putting it into pipeline, but should not be used in scripts
    - Instead of `function Alfa { "Help" }` use `function Alfa { return 'Help' }`
- Use [singular nouns in function/parameters names](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/UseSingularNouns.md)
- Variable naming
    - Local functions variables use classic **Camel Case** `$camelCase`
    - Global variables should have uppercase character and underscore. `$SCOOP_GLOBAL`
- Use single quotes for simple strings
- [Use correct casing for function names/parameters](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/UseCorrectCasing.md)

## Manifest creation

All official buckets are community-driven, and everyone can add, update, and edit manifests.
Pull-Requests are warmly welcomed.
The next few lines will guide you on how to write manifests, which pass our standards without any problems.

❗ If you haven't read the Wiki, please do it now. You can visit the [Scoop Wiki](https://github.com/lukesampson/scoop/wiki/App-Manifests) or the [exprimental external documentaion](https://scoop.netlify.com/concepts/#app-manifests) ❗

The Wiki gives you a fundamental insight into how manifests should look like and how everything works together.

A small overview of guidelines that you need to follow when writing manifests. (Explanation to each of them below)

1. Manifests need to be formatted as described in [.editorconfig file][.editorconfig]
    - 4 spaces indentation
    - Newline at the end of file
    - No trailing whitespace
    - Line endings have to be CRLF
1. Always include these informative properties:
    - `description`
    - `license`
1. Write readable/extendable code inside script blocks
1. [Test your auto-updates](https://github.com/lukesampson/scoop/wiki/App-Manifest-Autoupdate) before publishing a Pull-Request
1. Always inspect if the vendor of the application provides checksums for artifacts

### Manifest format

When Pull-Request is published, the AppVeyor pipeline is executed with various manifests errors.
Best practice for always passing all checks is to run [checkver][checkver] or [format][formatjson] scripts before submitting Pull-Request.

[checkver][checkver], [format][formatjson], and other scripts under the `bin` folder are PowerShell scripts that should run on all platforms (Linux, macOS with `pwsh`), so you are not tied with Windows platform.
All of them are ported into each bucket with prefilled parameters.

#### Manifest naming

All manifests name under official buckets should meet these conventions.

1. All characters should be lowercased
1. `-` is used as a separator when the application name contains space

<!-- @ScoopInstaller/maintainers Anything else? -->

#### Description

<!-- TODO some preface -->

- Do not mention application name
    - The application's name is needed only in case when the manifest name is different from the application's name. (in case of a more popular acronym for command-line utilities for example)
<!-- TODO other specifications -->

#### Properties order

Manifest consists of 7 main groups (regions) of properties. These properties (and their sub-properties) should be logically ordered from top to bottom as they are evaluated in the installation process.

The best order of all properties as follows:

1. Information region
    1. Version
    1. Description
    1. Homepage
    1. License
    1. Notes
1. Requirements
    1. Depends
    1. Suggest
1. Downloading
    1. Cookies
    1. Url
    1. Hash
1. Extraction
    1. Extract_dir
    1. Extract_to
1. Installation
    1. Pre_install
    1. Installer
    1. Post_Install
    1. Uninstall
1. Links
    1. Bin
    1. Shortcuts
    1. Modules
    1. Env_add_path
    1. Env_set
    1. Persist
1. Updating
    1. Checkver
    1. Autoudpate

### Readable code

You can specify `post_install`, `pre_install`, and `installer.script` blocks, which could be an array (or a simple string) with PowerShell code.
For these blocks, use the syntax as you would generally write PowerShell scripts (Follow PSScriptAnalyzer rules; See: [core codebase](#core-codebase)).

How script blocks should **NOT** look like: <https://github.com/lukesampson/scoop/blob/fa6ccc9471a29bf621c80a507d387a371293de75/bucket/jetbrains-toolbox.json#L32>
You can compare it with [refactored version](https://github.com/lukesampson/scoop-extras/blob/781a2128150505b4cd00ed4854a7af4160c0e772/bucket/jetbrains-toolbox.json#L12-L24) to see significant differences in readability.

### Autoupdates

❗ Always test auto-updates before posting a Pull-Request. ❗

The last step that should be done before submitting a Pull-Request is to run the [checkver][checkver] script with the `-Force` (`-f`) parameter for updating to the latest available version of the application and proper manifest format.

- Update all properties inside `autoupdate` property with actual values (URL, `extract_dir`, ...)
- Calculates or extracts checksums for all artifacts
- Formats the manifest to comfort standard

[README]: ../README.md
[.editorconfig]: ../.editorconfig
[checkver]: ../bin/checkver.ps1
[formatjson]: ../bin/formatjson.ps1
[Show-DeprecatedWarning]: https://github.com/lukesampson/scoop/blob/6141e46d6ae74b3ccf65e02a1c3fc92e1b4d3e7a/lib/core.ps1#L22-L36
[approved-verbs]: https://docs.microsoft.com/en-us/powershell/developer/cmdlet/approved-verbs-for-windows-powershell-commands
[commits]: https://www.conventionalcommits.org/en/v1.0.0-beta.4/#specification
