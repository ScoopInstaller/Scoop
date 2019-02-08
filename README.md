<p align="center">
<!--<img src="scoop.png" alt="Long live Scoop!"/>-->
    <h1 align="center">Scoop</h1>
</p>
<p align="center">
<b><a href="https://github.com/lukesampson/scoop#what-does-scoop-do">Features</a></b>
|
<b><a href="https://github.com/lukesampson/scoop#installation">Installation</a></b>
|
<b><a href="https://github.com/lukesampson/scoop/wiki">Documentation</a></b>
</p>

- - -
<p align="center" >
    <a href="https://github.com/lukesampson/scoop">
        <img src="https://img.shields.io/github/languages/code-size/lukesampson/scoop.svg" alt="Code Size" />
    </a>
    <a href="https://github.com/lukesampson/scoop">
        <img src="https://img.shields.io/github/repo-size/lukesampson/scoop.svg" alt="Repository size" />
    </a>
    <a href="https://ci.appveyor.com/project/lukesampson/scoop">
        <img src="https://ci.appveyor.com/api/projects/status/05foxatmrqo0l788?svg=true" alt="Build Status" />
    </a>
    <a href="https://gitter.im/lukesampson/scoop">
        <img src="https://badges.gitter.im/lukesampson/scoop.png" alt="Gitter Chat" />
    </a>
    <a href="https://github.com/lukesampson/scoop/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/lukesampson/scoop.svg" alt="License" />
    </a>
</p>

Scoop is a command-line installer for Windows.

## What does Scoop do?

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
scoop install aria2 curl grep sed less touch
scoop install python ruby go perl
```

If you've built software that you'd like others to use, Scoop is an alternative to building an installer (e.g. MSI or InnoSetup) — you just need to zip your program and provide a JSON manifest that describes how to install it.

## Requirements

* Windows 7 SP1+ / Windows Server 2008+
* [PowerShell 3](https://www.microsoft.com/en-us/download/details.aspx?id=34595) (or later) and [.NET Framework 4.5+](https://www.microsoft.com/net/download)
* PowerShell must be enabled for your user account e.g. `set-executionpolicy remotesigned -s currentuser`

## Installation

Run this command from your PowerShell to install scoop to its default location (`C:\Users\<user>\scoop`)
```powershell
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
```

Once installed, run `scoop help` for instructions.

The default setup is configured so all user installed programs and Scoop itself live in `C:\Users\<user>\scoop`.
Globally installed programs (`--global`) live in `C:\ProgramData\scoop`.
These settings can be changed through environment variables.

#### Install Scoop to a Custom Directory
```powershell
[environment]::setEnvironmentVariable('SCOOP','D:\Applications\Scoop','User')
$env:SCOOP='D:\Applications\Scoop'
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
```

#### Configure Scoop to install global programs to a Custom Directory
```powershell
[environment]::setEnvironmentVariable('SCOOP_GLOBAL','F:\GlobalScoopApps','Machine')
$env:SCOOP_GLOBAL='F:\GlobalScoopApps'
```

## [Documentation](https://github.com/lukesampson/scoop/wiki)

## Multi-connection downloads with `aria2`
Scoop can utilize [`aria2`](https://github.com/aria2/aria2) to use multi-connection downloads. Simply install `aria2` through Scoop and it will be used for all downloads afterward.
```powershell
scoop install aria2
```

You can tweak the following `aria2` settings with the `scoop config` command:

- aria2-enabled (default: true)
- [aria2-retry-wait](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-retry-wait) (default: 2)
- [aria2-split](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-s) (default: 5)
- [aria2-max-connection-per-server](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-x) (default: 5)
- [aria2-min-split-size](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-k) (default: 5M)

## Inspiration

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

## What sort of apps can Scoop install?

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.


### Support this project

If you find Scoop useful and would like to support ongoing development and maintenance, here's how:

* [PayPal](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DM2SUH9EUXSKJ) (one-time donation)
