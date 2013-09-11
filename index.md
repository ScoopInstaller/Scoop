---
layout: default
---

### Scoop installs the tools you know and love

    scoop install curl
<br>

### Get comfortable on the Windows command line

Looking for familiar Unix tools? Tired of Powershell&rsquo;s *Verb-Noun* verbosity? Scoop
helps you get the
[programs](https://github.com/lukesampson/scoop/tree/master/bucket) you
[need](https://github.com/lukesampson/scoop-extras),
with a minimal amount of point-and-clicking.

<br>

### Demo

<iframe width="640" height="360" src="//www.youtube.com/embed/a85QLUJ0Wbs?rel=0" frameborder="0" allowfullscreen="true">
</iframe>

<br>

<br>

# Installs in seconds

Make sure [Powershell 3](http://www.microsoft.com/en-us/download/details.aspx?id=34595)
is installed, then run:

    iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

**Note:** if you get an error you might need to change the execution policy
(i.e. enable Powershell) with `set-executionpolicy unrestricted -s cu`
