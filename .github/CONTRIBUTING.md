# Contributing

There are 2 main ways how to contribute into Scoop codebase.

1. [Extending codebase of scoop itself](#core-codebase)
1. [Writing / updating manifests](#manifest-creation)

If you have qustion regarding scoop overall, feel free to head into community discord server. (Invitation link inside [README][README])

## Core codebase

You can contribute into core codebase these ways:

1. [Implement new features](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Aenhancement)
1. [Fix bugs](https://github.com/lukesampson/scoop/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Abug)
1. Identify / report reproducible steps of issues

Scoop's core codebase started moving towards standard / preferred powershell code style. Mainly with adoption of `Verb-Noun` naming.
Starting from April 2019 use `Verb-Noun` naming for functions when manipulating with codebase.

TODO:

- Verb-Noun refactor flow
    - Move code to new `Verb-Noun` function
    - Add Depreaction warning
    - Call new function in old
    - Replace all references to old function
- functions parameters, cmdletbinding(), naming, ...
    - Why cmdletbinding
        - Advanced function (practically equalled with scripts)
        - Default parameters (Debug, Verbose, ...)
- No aliases
    - Obvious reasons

## Manifest creation

All official buckets are community driven and everyone can add / update / edit them.
All kind of PRs are warmly welcomed. Next few lines will guide you how to write manfifests, which pass PR without any problems.

❗ If you haven't read wiki please do it now. You could visit [github project wiki](https://github.com/lukesampson/scoop/wiki/App-Manifests) or [exprimental external documentaion](https://scoop.netlify.com/concepts/#app-manifests) ❗

Wiki gives you basic insights how manifests should look like and how everything work together.

Let's fast mention some points, which you need to follow when writing manifests. (Explanation to each of them below)

1. Manifests need to be formated as described in [.editorconfig file][.editorconfig]
    - 4 spaces indentation
    - New line at end of file
    - No trailing whitespace
1. Always include these informative properties:
    - `description`
    - `license`
1. Write readable / extendable code inside script blocks
1. Test your autoupdates before publishing PR
1. Always inspect if vendor of application provides checksums for artifacts

### Manifest format

When you publish PR, appveyor pipeline will be executed and check for formatting errors inside your manifests.
Best practise for always passing PR is to run [checkver][checkver] or [format][formatjson] binary before posting PR.

Binaries are powershell scripts which should run on all platforms (Linux, MacOS with pwsh), so you are not tied with Windows platform.

### Readable code

You can specify `post_install`, `pre_install`, `install.script` blocks, which could be array (or simple string) with powershell code.
For these blocks use syntax as you would normally write powershell scripts (Follow PSScriptAnalyzer rules; You could read about it [core codebase](#core-codebase)).

How script blocks should **NOT** look like: <https://github.com/lukesampson/scoop/blob/fa6ccc9471a29bf621c80a507d387a371293de75/bucket/jetbrains-toolbox.json#L32>

### Autoupdates

❗ Always test your autoupdates before posting PR ❗

Last step what you should do before posting PR is to run [checkver][checkver] binary with `-Force` (`-f`) parameter.
This will check for latest version of manifest and update to it.

- Update all properties inside `autoupdate` property with actual values (url, extract_dir, ...)
- Calculate / Extract hash for actual artifacts
- Format manifest to comfort standard

[README]: ../README.md
[.editorconfig]: ../.editorconfig
[checkver]: ../bin/checkver.ps1
[formatjson]: ../bin/formatjson.ps1
