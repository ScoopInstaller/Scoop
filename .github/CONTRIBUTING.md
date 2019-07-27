# Contributing

There are two main ways how to contribute to the Scoop codebase.

1. [Extending codebase of scoop itself](#core-codebase)
1. [Writing/updating manifests](#manifest-creation)

If you have a question regarding Scoop overall, feel free to head into community Discord server. (Invitation link inside [README][README])

## Core codebase

You can contribute to core codebase these ways:

1. [Implement new features](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Aenhancement)
1. [Fix bugs](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Abug)
1. Identify/report reproducible steps of issues

Scoop's core codebase started moving towards standard/preferred PowerShell code style. Mainly with the adoption of [`Verb-Noun`][approved-verbs] naming.
Starting from April 2019 use `Verb-Noun` naming for functions when manipulating the codebase.

### How to properly deprecate function

When you want to refactor any function, keep in mind that original function need to be kept (With same name, parameters, return values).
Some internal functions are used inside manifests and if you would remove them all these manifests could not be installed.

1. Create new funtion with Verb-Noun name
    1. Use [`[CmdletBinding()]`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute?view=powershell-6)
        - This will allow functions to benefit from advantages of compiled cmdlets
            - Default parameters will be added (Debug, Verbose, ErrorAction, ...)
1. Change body of old function to this:

```powershell
function old_f {
    Show-DeprecatedWarning $MyInvocation 'New-FunctionName'
    New-FunctionName -SomeParametersYouNeedToAchieveSameBehaviour
}
```

See [Decompress module](https://github.com/lukesampson/scoop/blob/1caaed8f3d51d141c6cafe7dc690b7dc08802702/lib/decompress.ps1) for specific example.

### General code sins to avoid and restricitons to follow

There are few misdemeanors that often show up in PRs and code base.
Keep source code more tidier and cleaner with these.

- [Cmdlet aliases](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/AvoidUsingCmdletAliases.md)
    - Never use aliases
    - Aliases are usefull only in interactive (terminal) usage
    - Code readibility is significantly lowered
    - Also aliases could be different in different workspaces / system versions
- Short format of function parameters
    - Powershell allows you to use short version of parameters
        - Instead of `Write-Host -ForegroundColor Yellow` you can use `Write-Host -f Yellow`
        - This should be avoid due to compatibility with newer versions of powershell / functions
    - When there are parameters with same starting characters it will lead to `Ambiguous` parameter error (`gci -p` for example)
- Returning data from function without `return` statement
    - Powershell allow to "return" data from function with simply putting it into pipeline, but should not be used in scripts
    - Instead of `function Alfa { "Help" }` use `function Alfa { return "Help" }`
- [Plural nouns in function names](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/UseSingularNouns.md)
- Local functions variables use classic **Camel Case** `$camelCase`
- Use single quotes for simple strings
- [Use correct casing for function names / parameters](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/UseCorrectCasing.md)

## Manifest creation

All official buckets are community driven and everyone can add, update and edit them.
Pull-Requests are warmly welcomed.
The next few lines will guide you on how to write manifests, which pass our standards without any problems.

❗ If you haven't read the Wiki please do it now. You could visit the [projects Wiki](https://github.com/lukesampson/scoop/wiki/App-Manifests) or the [exprimental external documentaion](https://scoop.netlify.com/concepts/#app-manifests) ❗

The Wiki gives you a basic insight on how manifests should look like and how everything works together.

A small overview of guidelines which you need to follow when writing manifests. (Explanation to each of them below)

1. Manifests need to be formatted as described in [.editorconfig file][.editorconfig]
    - 4 spaces indentation
    - New line at end of file
    - No trailing whitespace
1. Always include these informative properties:
    - `description`
    - `license`
1. Write readable/extendable code inside script blocks
1. Test your auto-updates before publishing a Pull-Request
1. Always inspect if the vendor of the application provides checksums for artifacts

### Manifest format

When you publish a Pull-Request the AppVeyor pipeline will be executed and check for formatting errors inside your manifests.
Best practice for always passing all checks is to run [checkver][checkver] or [format][formatjson] scripts before posting Pull-Request.

These are PowerShell scripts which should run on all platforms (Linux, MacOS with `pwsh`), so you are not tied with Windows platform.

### Readable code

You can specify `post_install`, `pre_install` and `installer.script` blocks, which could be an array (or a simple string) with PowerShell code.
For these blocks use the syntax as you would normally write PowerShell scripts (Follow PSScriptAnalyzer rules; See: [core codebase](#core-codebase)).

How script blocks should **NOT** look like: <https://github.com/lukesampson/scoop/blob/fa6ccc9471a29bf621c80a507d387a371293de75/bucket/jetbrains-toolbox.json#L32>
You can compare it with [refactored version](https://github.com/lukesampson/scoop-extras/blob/781a2128150505b4cd00ed4854a7af4160c0e772/bucket/jetbrains-toolbox.json#L12-L24) to see significant differences.

### Autoupdates

❗ Always test your auto-updates before posting a Pull-Request ❗

The last step what you should do before posting a Pull-Request is to run the [checkver][checkver] script with the `-Force` (`-f`) parameter.
This will check for the latest version of the program (specified within the `checkver` property) and update the manifest file.

- Update all properties inside `autoupdate` property with actual values (URL, `extract_dir`, ...)
- Calculates or extracts checksums for all artifacts
- Formats the manifest to comfort standard

[README]: ../README.md
[.editorconfig]: ../.editorconfig
[checkver]: ../bin/checkver.ps1
[formatjson]: ../bin/formatjson.ps1
[Show-DeprecatedWarning]: https://github.com/lukesampson/scoop/blob/6141e46d6ae74b3ccf65e02a1c3fc92e1b4d3e7a/lib/core.ps1#L22-L36
[approved-verbs]: https://docs.microsoft.com/en-us/powershell/developer/cmdlet/approved-verbs-for-windows-powershell-commands
