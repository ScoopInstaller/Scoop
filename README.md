Scoop [![Build status](https://ci.appveyor.com/api/projects/status/bfsfu6bwyviaqjhi/branch/master?svg=true)](https://ci.appveyor.com/project/deevus/scoop/branch/master)
=====

Scoop is a command-line installer for windows.

Requirements:

* [PowerShell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy unrestricted -s cu`

To install:

    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    
Once installed, run `scoop help` for instructions.

What does Scoop do?
-------------------

Scoop installs programs from the command line with a minimal amount of friction. It tries to eliminate things like:
* Permission popup windows
* GUI wizard-style installers
* Path pollution from installing lots of programs
* Unexpected side-effects from installing and uninstalling programs
* The need to find and install dependencies
* The need to perform extra setup steps to get a working program

Scoop is very scriptable, so you can run repeatable setups to get your environment just the way you like, e.g.:

```powershell
scoop install sudo
sudo scoop install 7zip git openssh --global
scoop install curl grep sed less tail touch
scoop install python ruby go perl
```

If you've built software that you'd like others to use, Scoop is an alternative to building an installer (e.g. MSI or InnoSetup)—you just need to zip your program and provide a JSON manifest that describes how to install it.

### [Documentation](https://github.com/lukesampson/scoop/wiki)

Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

What sort of apps can Scoop install?
------------------------------------

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.