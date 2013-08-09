Scoop (alpha)
=============

Scoop is a simple command-line installer for windows.

Requirements:

* [PowerShell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy unrestricted -s cu`

To install:

    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    
Once installed, run `scoop help` for instructions.

What does Scoop do?
-------------------

* Quickly installs tools and utilities.
* Makes sharing scripts and utilities easy.
* Enables productive scripting in Windows using a composition of collected utilities.


Scoop vs [Chocolatey](http://chocolatey.org)
--------------------------------------------

Pros:

* **Installs to ~/appdata/local.**
* **No UAC popups, doesn't require admin privileges*.** *Usually. InnoSetup installers are the exception when no other install method is available.
* **Doesn't pollute your path.** Scoop adds just one directory to your path, no matter how many apps you install with it. Since symlinks are broken on Windows, this is done by creating shim programs in your Scoop bin directory.
* **Doesn't use NuGet.** NuGet helps manage library dependencies for software. Scoop doesn't try to stretch NuGet into doing something it isn't designed to do.
* **Packages are easier to make.** Scoop packages can be written in JSON in any text editor—nothing else needed. Check out a [simple example](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json), and [something slightly more complex](https://github.com/lukesampson/scoop/blob/master/bucket/git.json). Chocolatey packages, on the other hand, require NuGet and .nuspecs—and then you have to write a PS script anyway to do the install. It downloads the 
* **Simpler app repo.** Scoop just uses git for it's app repo. You can create your own repo, or even just a single file that describes an app to install.


Cons:
* **Not as many apps.** Scoop has [nowhere near the number of apps](https://github.com/lukesampson/scoop/tree/master/bucket) that [Chocolatey has](http://chocolatey.org/packages).
* **Can't target a specific version of an app.**


Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

What sort of apps can Scoop install?
------------------------------------

The apps that install best with Scoop are compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.