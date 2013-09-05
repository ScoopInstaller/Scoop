Scoop
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

How is this different to [Chocolatey](http://chocolatey.org)?
-------------------------------------------------------------

* **Installs to ~/appdata/local/ by default** You can set up your own programs and not worry that they'll interfere with other users' programs (or theirs with yours, perhaps more importantly). You can optionally choose to install programs system-wide if you have admin rights.
* **No UAC popups, doesn't require admin rights*.** Since programs are installed just for your user account, you won't be interrupted by UAC popups. InnoSetup installers are the exception when no other install method is available.
* **Doesn't pollute your path.** Where possible, Scoop puts your program shims in a single directory and just adds that to your path
* **Doesn't use NuGet.** NuGet is a great solution to the problem of managing software library dependencies. Scoop avoids this problem altogether: each program you install is isolated and independent.
* **Simpler than packaging** Scoop isn't a package manager, rather it reads plain JSON manifests that describe how to install a program and it's dependencies.
* **Simpler app repo.** Scoop just uses git for it's app repo. You can create your own repo, or even just a single file that describes an app to install.
* **Can't install a specific version of a program.** Scoop doesn't allow installing every version release of a program, just the latest stable version. There are some exceptions, e.g. Python 2.7 and Ruby 1.9 which are commonly required—these can be installed from `python27` and `ruby19`.
* **Focuses on developer tools.** While it would be easy to install Skype with Scoop, this will probably never be in Scoop's main bucket (app repository). Scoop focuses on open-source, command-line developer tools.

Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

What sort of apps can Scoop install?
------------------------------------

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.