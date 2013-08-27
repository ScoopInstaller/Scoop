---
layout: default
---

### Scoop installs tools and utilities

    scoop install curl
<br>

### Get comfortable on the Windows command line

Looking for familiar UNIX tools? Tired of Powershell&rsquo;s *Verb-Noun* verbosity? Scoop
helps you get
[the programs you need](https://github.com/lukesampson/scoop/tree/master/bucket),
with a minimal amount of point-and-clicking.

<br>

# Installs in seconds

Make sure [Powershell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
is installed, then run:

    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

**Note:** if you get an error you might need to change the execution policy
(i.e. enable Powershell) with `set-executionpolicy unrestricted -s cu`