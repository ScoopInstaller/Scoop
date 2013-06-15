Scoop
=====

Scoop is a simple package manager for Windows.

To install:

    iex (new-object net.webclient).downloadstring('https://raw.github.com/lukesampson/scoop/master/bin/install.ps1')
    
Once installed, run `scoop help` for instructions.


Scoop vs other package managers for Windows
-------------------------------------------

* **Doesn't pollute your path.** Scoop adds just one directory to your path, no matter how many apps you install with it.
* **Doesn't use NuGet.** NuGet helps manage library dependencies for software. Scoop doesn't try to stretch NuGet to doing something it was never designed to do.
* **Packages are easier to define.** Scoop packages can be written in JSON in any text editor—nothing else needed.
* **Better interface.** Subjective, but true.