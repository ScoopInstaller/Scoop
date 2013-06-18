Scoop
=====

Scoop is a simple package manager for Windows.

Requirements:

* [PowerShell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy unrestricted -s cu`

To install:

    iex (new-object net.webclient).downloadstring('https://raw.github.com/lukesampson/scoop/master/bin/install.ps1')
    
Once installed, run `scoop help` for instructions.

What problems Scoop is trying to solve?
---------------------------------------

*todo: these aren't really problems—rewrite to be more provocative and insulting?*

* Quickly install the tools and utilities you need to make your system useful.
* Make sharing scripts and utilities easy.
* Enable productive scripting in Windows using a composition of collected utilities.


Scoop vs [Chocolatey](http://chocolatey.org)
--------------------------------------------

Pros:

* **Doesn't pollute your path.** Scoop adds just one directory to your path, no matter how many apps you install with it.
* **Doesn't use NuGet.** NuGet helps manage library dependencies for software. Scoop doesn't try to stretch NuGet to doing something it was never designed to do.
* **Packages are easier to make.** Scoop packages can be written in JSON in any text editor—nothing else needed. Chocolatey packages require NuGet and 'nuspecs', and then you have to write a PS script anyway to do the install.
* **Simpler app repo.** Scoop just uses git for it's app 'bucket'. You can create your own repo, or even just a single file that describes an app to install.
* **Better interface.** Subjective, but true.

Cons:
* **Not as many apps.** Scoop has [nowhere near the number of apps](https://github.com/lukesampson/scoop/tree/master/bucket) that Chocolatey has. Contributions via pull-request are welcome!

Inspiration
-----------

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)