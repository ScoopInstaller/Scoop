<p align="center">
<!--<img src="scoop.png" alt="Long live Scoop!"/>-->
    <h1 align="center">Scoop</h1>
</p>
<p align="center">
<b><a href="https://github.com/ScoopInstaller/Scoop#what-does-scoop-do">Features</a></b>
|
<b><a href="https://github.com/ScoopInstaller/Scoop#installation">Installation</a></b>
|
<b><a href="https://github.com/ScoopInstaller/Scoop/wiki">Documentation</a></b>
</p>

- - -
<p align="center" >
    <a href="https://github.com/ScoopInstaller/Scoop">
        <img src="https://img.shields.io/github/languages/code-size/ScoopInstaller/Scoop.svg" alt="Code Size" />
    </a>
    <a href="https://github.com/ScoopInstaller/Scoop">
        <img src="https://img.shields.io/github/repo-size/ScoopInstaller/Scoop.svg" alt="Repository size" />
    </a>
    <a href="https://github.com/ScoopInstaller/Scoop/actions/workflows/ci.yml">
        <img src="https://github.com/ScoopInstaller/Scoop/actions/workflows/ci.yml/badge.svg" alt="Scoop Core CI Tests" />
    </a>
    <a href="https://discord.gg/s9yRQHt">
        <img src="https://img.shields.io/badge/chat-on%20discord-7289DA.svg" alt="Discord Chat" />
    </a>
    <a href="https://gitter.im/lukesampson/scoop">
        <img src="https://badges.gitter.im/lukesampson/scoop.png" alt="Gitter Chat" />
    </a>
    <a href="./LICENSE">
        <img src="https://img.shields.io/badge/license-UNLICENSE%20or%20MIT-blue" alt="License" />
    </a>
</p>

Scoop is a command-line installer for Windows.

## What does Scoop do?

Scoop installs programs from the command line with a minimal amount of friction. It:

- Eliminates permission popup windows
- Hides GUI wizard-style installers
- Prevents PATH pollution from installing lots of programs
- Avoids unexpected side-effects from installing and uninstalling programs
- Finds and installs dependencies automatically
- Performs all the extra setup steps itself to get a working program

Scoop is very scriptable, so you can run repeatable setups to get your environment just the way you like, e.g.:

```powershell
scoop install sudo
sudo scoop install 7zip git openssh --global
scoop install aria2 curl grep sed less touch
scoop install python ruby go perl
```

If you've built software that you'd like others to use, Scoop is an alternative to building an installer (e.g. MSI or InnoSetup) — you just need to zip your program and provide a JSON manifest that describes how to install it.

## Installation

Run the following command from a **non-admin** PowerShell to install scoop to its default location `C:\Users\<YOUR USERNAME>\scoop`.

```powershell
iwr -useb get.scoop.sh | iex
```

Advanced installation instruction and full documentation of the installer are available in [ScoopInstaller/Install](https://github.com/ScoopInstaller/Install). Please create new issues there if you have questions about the installation.

## [Documentation](https://github.com/ScoopInstaller/Scoop/wiki)

## Multi-connection downloads with `aria2`

Scoop can utilize [`aria2`](https://github.com/aria2/aria2) to use multi-connection downloads. Simply install `aria2` through Scoop and it will be used for all downloads afterward.

```powershell
scoop install aria2
```

By default, `scoop` displays a warning when running `scoop install` or `scoop update` while `aria2` is enabled. This warning can be suppressed by running `scoop config aria2-warning-enabled false`.

You can tweak the following `aria2` settings with the `scoop config` command:

- aria2-enabled (default: true)
- aria2-warning-enabled (default: true)
- [aria2-retry-wait](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-retry-wait) (default: 2)
- [aria2-split](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-s) (default: 5)
- [aria2-max-connection-per-server](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-x) (default: 5)
- [aria2-min-split-size](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-k) (default: 5M)
- [aria2-options](https://aria2.github.io/manual/en/html/aria2c.html#options) (default: )

## Inspiration

- [Homebrew](http://mxcl.github.io/homebrew/)
- [sub](https://github.com/37signals/sub#readme)

## What sort of apps can Scoop install?

The apps that install best with Scoop are commonly called "portable" apps: i.e. compressed program files that run stand-alone when extracted and don't have side-effects like changing the registry or putting files outside the program directory.

Since installers are common, Scoop supports them too (and their uninstallers).

Scoop is also great at handling single-file programs and Powershell scripts. These don't even need to be compressed. See the [runat](https://github.com/ScoopInstaller/Main/blob/master/bucket/runat.json) package for an example: it's really just a GitHub gist.

### Contribute to this project

If you'd like to improve Scoop by adding features or fixing bugs, please read our [Contributing Guide](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md).

### Support this project

If you find Scoop useful and would like to support ongoing development and maintenance, here's how:

- [PayPal](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DM2SUH9EUXSKJ) (one-time donation)

## Known application buckets

The following buckets are known to scoop:

- [main](https://github.com/ScoopInstaller/Main) - Default bucket for the most common (mostly CLI) apps
- [extras](https://github.com/ScoopInstaller/Extras) - Apps that don't fit the main bucket's [criteria](https://github.com/ScoopInstaller/Scoop/wiki/Criteria-for-including-apps-in-the-main-bucket)
- [games](https://github.com/Calinou/scoop-games) - Open source/freeware games and game-related tools
- [nerd-fonts](https://github.com/matthewjberger/scoop-nerd-fonts) -  Nerd Fonts
- [nirsoft](https://github.com/kodybrown/scoop-nirsoft) - Almost all of the [250+](https://rasa.github.io/scoop-directory/by-apps#kodybrown_scoop-nirsoft) apps from [Nirsoft](https://nirsoft.net)
- [sysinternals](https://github.com/niheaven/scoop-sysinternals) - Sysinternals Suite and all individual application from [Microsoft](https://learn.microsoft.com/sysinternals/)
- [java](https://github.com/ScoopInstaller/Java) - A collection of Java development kits (JDKs), Java runtime engines (JREs), Java's virtual machine debugging tools and Java based runtime engines.
- [nonportable](https://github.com/ScoopInstaller/Nonportable) - Non-portable apps (may require UAC)
- [php](https://github.com/ScoopInstaller/PHP) - Installers for most versions of PHP
- [versions](https://github.com/ScoopInstaller/Versions) - Alternative versions of apps found in other buckets

The main bucket is installed by default. To add any of the other buckets, type:

```console
scoop bucket add bucketname
```

For example, to add the extras bucket, type:

```console
scoop bucket add extras
```

## Other application buckets

Many other application buckets hosted on Github can be found in the [Scoop Directory](https://rasa.github.io/scoop-directory/) or via [other search engines](https://rasa.github.io/scoop-directory/#other-search-engines).
