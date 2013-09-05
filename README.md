Scoop
=====

Scoop is a command-line installer for windows.

Requirements:

* [PowerShell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy unrestricted -s cu`

To install:

    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    
Once installed, run `scoop help` for instructions.

#### [What Does Scoop Do?](https://github.com/lukesampson/scoop/wiki/What-Does-Scoop-Do%3F)
[Documentation](https://github.com/lukesampson/scoop/wiki)

Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

What sort of apps can Scoop install?
------------------------------------

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.