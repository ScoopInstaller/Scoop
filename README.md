Scoop (alpha)
=============

Scoop is a simple package manager for Windows, designed for people who like working on the command-line.

Requirements:

* [PowerShell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy unrestricted -s cu`

To install:

    iex (new-object net.webclient).downloadstring('https://raw.github.com/lukesampson/scoop/master/bin/install.ps1')
    
Once installed, run `scoop help` for instructions.

What does Scoop do?
-------------------

* Quickly installs the tools and utilities you need, with minimum fuss.
* Makes sharing scripts and utilities easy.
* Enables productive scripting in Windows using a composition of collected utilities.
* Doesn't follow PowerShell conventions.


Scoop vs [Chocolatey](http://chocolatey.org)
--------------------------------------------

Pros:

* **Doesn't pollute your path.** Scoop adds just one directory to your path, no matter how many apps you install with it. Since symlinks are broken on Windows, this is done by creating stub programs in your Scoop bin directory.
* **Doesn't use NuGet.** NuGet helps manage library dependencies for software. Scoop doesn't try to stretch NuGet into doing something it isn't designed to do.
* **Packages are easier to make.** Scoop packages can be written in JSON in any text editor—nothing else needed. Check out a [simple example](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json), and [something slightly more complex](https://github.com/lukesampson/scoop/blob/master/bucket/git.json). Chocolatey packages, on the other hand, require NuGet and .nuspecs—and then you have to write a PS script anyway to do the install. It downloads the 
* **Simpler app repo.** Scoop just uses git for it's app repo. You can create your own repo, or even just a single file that describes an app to install.


Cons:
* **Not as many apps.** Scoop has [nowhere near the number of apps](https://github.com/lukesampson/scoop/tree/master/bucket) that [Chocolatey has](http://chocolatey.org/packages).


Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

What sort of apps can Scoop install?
------------------------------------

The apps that install best with Scoop are compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.