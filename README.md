<p align="center">
<!--<img src="scoop.png" alt="Long live Scoop!"/>-->
    <h1 align="center">Scoop</h1>
</p>
<p align="center">
<b><a href="https://github.com/lukesampson/scoop#what-does-scoop-do">特点</a></b>
|
<b><a href="https://github.com/lukesampson/scoop#installation">如何安装？</a></b>
|
<b><a href="https://github.com/lukesampson/scoop/wiki">文档</a></b>
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

Scoop是 Windows 上的的命令行软件安装程序。

## Scoop 有什么作用？

Scoop 希望以最小的代价从命令行安装程序。它试图解决以下的问题:
* UAC 弹出窗口
* GUI 向导式安装程序
* 安装大量程序造成的路径污染
* 安装和卸载程序时出现意外的副作用
* 需要查找并安装依赖项
* 需要执行额外的设置才能让程序起效

Scoop 非常易于使用，因此你可以快速进行设置，以你喜欢的方式配置你的环境。

```powershell
scoop install sudo
sudo scoop install 7zip git openssh --global
scoop install aria2 curl grep sed less touch
scoop install python ruby go perl
```

如果你构建了你希望其他人使用的软件，Scoop 是构建 .MSI 或 .EXE 安装程序的替代方法，你只需要压缩程序并提供描述如何安装它的 JSON 清单。

* Windows 7 SP1+ / Windows Server 2008+
* [PowerShell 3](https://www.microsoft.com/en-us/download/details.aspx?id=34595) (或更高版本) 与 [.NET Framework 4.5+](https://www.microsoft.com/net/download)
* 必须为你的用户账户启用 PowerShell，使用
  `set-executionpolicy remotesigned -s currentuser`

## 安装

从 PowerShell 运行此命令以将 Scoop 安装到其默认位置（`C:\Users\<你的用户名>\scoop`）
```powershell
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
```

安装完成后，运行 ` scoop help ` 获取说明。

默认设置已配置，因此所有用户安装的程序和Scoop本身都位于你的` C：\Users\<你的用户名>\scoop `中。
全局安装的程序（`--global`）存在于 ` C：\ProgramData\scoop ` 中。
你可以通过环境变量更改这些设置。

#### 将 Scoop 安装到自定义目录（例子中，自定义目录为 D:\Applications\Scoop）
```powershell
[environment]::setEnvironmentVariable('SCOOP','D:\Applications\Scoop','User')
$env:SCOOP='D:\Applications\Scoop'
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
```

#### 配置 Scoop 以将全局程序安装到自定义目录
```powershell
[environment]::setEnvironmentVariable('SCOOP_GLOBAL','F:\GlobalScoopApps','Machine')
$env:SCOOP_GLOBAL='F:\GlobalScoopApps'
```

## [文档](https://github.com/lukesampson/scoop/wiki)

## 使用 `aria2` 进行多线程下载
Scoop可以利用 [`aria2`](https://github.com/aria2/aria2)进行多线程下载。只用通过Scoop安装 `aria2` ，之后就会用`aria2`进行所有下载
```powershell
scoop install aria2
```

你可以使用`scoop config`命令调整以下`aria2`设置：

- aria2-enabled (default: true)  是否启用aria2
- [aria2-retry-wait](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-retry-wait) (default: 2)  重试等待
- [aria2-split](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-s) (default: 5)  单任务连接数
- [aria2-max-connection-per-server](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-x) (default: 5)  最大线程数
- [aria2-min-split-size](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-k) (default: 5M) 最小单文件分割尺寸

## 其他

* [Homebrew](http://mxcl.github.io/homebrew/)
* [sub](https://github.com/37signals/sub#readme)

## Scoop 可以安装什么类型的应用程序?

使用 Scoop 最适合安装的应用程序通常称为“便携式”应用程序：即在解压缩时独立运行的压缩程序文件，并且没有诸如更改注册表或将文件放在程序目录之外的副作用。

由于安装程序很常见，Scoop 也支持它们（以及它们的卸载程序）。

Scoop 在处理单文件程序和 Powershell 脚本方面也很出色。 这些甚至不需要压缩。 请参阅[ runat ](https://github.com/lukesampson/scoop/blob/master/bucket/runat.json)包作为示例：它实际上只是一个 GitHub 仓库。

Scoop 默认仓库的要求十分苛刻，许多应用无法安装，因此，请手动添加 bucket，你可以通过`scoop bucket known`查询 Scoop 还能直接识别哪些 bucket。并通过`scoop bucket add bucket `的格式添加 bucket。

### [社区 bucket 列表](https://github.com/rasa/scoop-directory/blob/master/by-score.md)

我们可以通过这样的方式来将社区维护的 bucket 添加至本机的 Scoop bucket 列表：

```
scoop bucket add <仓库名> <仓库地址>
```

之后，如果我们要安装某仓的某项 App，直接通过下面的这个命令安装即可：

```
scoop install < bucket 名>/<App 名>
```

往往，Google 搜索「App 的名字 + scoop」就可以找到我们想要安装 App 的仓库有没有存在。


### 支持这个项目

如果你认为 Scoop 很有用并且希望支持正在进行的开发和维护，请按通过以下渠道捐助：

* [PayPal](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DM2SUH9EUXSKJ) (一次性捐赠)
