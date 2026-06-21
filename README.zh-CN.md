<div align="center">
  <img src="./logo_dark.png" alt="QuickDoc 图标" width="112">
  <h1>QuickDoc</h1>
  <p>从 Finder 右键菜单和工具栏直接新建常用文件。</p>
  <p>
    <a href="https://github.com/SkyImplied/QuickDoc/releases/tag/v1.6.0"><img src="https://img.shields.io/badge/version-v1.6.0-blue" alt="版本 v1.6.0"></a>
    <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?logo=apple" alt="平台 macOS 13+">
    <img src="https://img.shields.io/badge/built%20with-Swift-F05138?logo=swift&logoColor=white" alt="使用 Swift 构建">
    <a href="https://github.com/SkyImplied/QuickDoc/releases/download/v1.6.0/QuickDoc-1.6.0.dmg"><img src="https://img.shields.io/badge/download-DMG-brightgreen?logo=apple&logoColor=white" alt="下载 DMG"></a>
    <a href="https://github.com/SkyImplied/QuickDoc/releases"><img src="https://img.shields.io/github/downloads/SkyImplied/QuickDoc/total?label=downloads" alt="下载量"></a>
  </p>
  <p>
    <a href="README.md">English</a> | 简体中文 | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ja.md">日本語</a>
  </p>
</div>

QuickDoc 是一个围绕 macOS Finder Sync 扩展构建的效率工具。它会在 Finder 右键菜单中加入一个实用的“新建文件”子菜单；从 v1.3 开始，它还支持把 QuickDoc 添加到 Finder 工具栏，从工具栏直接调用新建文件能力。

## v1.6.0 更新亮点

- 修复在云盘、外置硬盘访达中通过工具栏调用 QuickDoc 时，复制和剪切功能失效的问题。
- 新增外置硬盘访达右键菜单快捷调用支持。旧版本只支持通过工具栏调用；云盘受限于 Apple 政策，暂时未支持右键直接调用，仍请通过工具栏调用。
- 美化通过 DMG 安装时的安装界面。

### 外置硬盘访达右键菜单

<p align="center">
  <img src="./photos/支持外置硬盘访达调用右键菜单功能.png" alt="QuickDoc 外置硬盘访达右键菜单" width="680">
</p>

### 改进的 DMG 安装界面

<p align="center">
  <img src="./photos/改进的dmg安装界面.png" alt="QuickDoc 改进的 DMG 安装界面" width="680">
</p>

## v1.5.5 更新亮点

- “复制当前路径”现在会跟随 Finder 当前选择：未选中文件时复制当前文件夹路径，选中文件或文件夹时复制所选项目的完整路径。
- “通用设置”中已将“终端直达”和“路径复制”拆分为两个独立板块，终端选择与路径复制规则不再混在一起。
- 优化路径复制说明，让启用前就能清楚理解“复制文件夹路径”和“复制所选项目路径”的区别。

## v1.5.4 更新亮点

- 新增自定义文件模板功能，可为已启用的文件类型上传自己的模板文档，不再只能新建空白默认文档。
- 新增按文件类型分组的模板管理板块，支持自定义右键菜单显示名、显示/隐藏、排序、重命名和删除。
- Finder 右键的“新建文件”菜单在某个文件类型存在可显示模板时，会自动变成三级菜单，并保留“空白默认文档”作为第一个选项。
- 自定义文件类型统一使用 `icons/空白.png` 图标；模板管理区只展示已在上方新建文件类型设置中启用的类型。

### 自定义文件模板

上传自己的模板文档后，可以设置右键菜单里显示的名字，并决定是否立刻显示到 Finder 菜单中。

![QuickDoc 自定义文件模板](./photos/自定义文件模版.png)

当某个文件类型有可显示模板时，Finder 右键菜单会在该类型下展开三级菜单。

![QuickDoc 自定义文件模板三级菜单](./photos/自定义文件模版三级菜单.png)

## v1.5.2 更新亮点

- 修复一些已知问题
- 优化软件使用体验，更新“关于”页面中的功能介绍与联系信息
- 优化通过 DMG 安装的软件安装流程，安装窗口现在拥有更清晰的拖拽指引、更大的图标、居中的内容布局与更清晰的 Retina 文案

## v1.5.1 更新亮点

- 修复通过 Finder 右键新建 PowerPoint（`.pptx`）后，PowerPoint 提示文件内容有问题并需要修复的情况
- 更新内置空白 PPTX 模板，补齐 PowerPoint 需要的母版、版式、主题、文档属性等标准结构

## v1.5.0 更新亮点

- “在终端中打开”新增第三方自定义终端支持，用户可以选择自己常用的终端 App，不再局限于系统终端
- “通用”设置页会展示当前选定终端的图标、名称与路径，并提供“更换终端 App”和“恢复系统终端”两个直接操作
- 内置文件类型 icons 进行统一化风格重构，整体视觉更一致

### 自定义终端 App

你可以在“通用”设置页选择偏好的终端 App。之后从 Finder 右键菜单打开当前文件夹时，QuickDoc 会使用你选定的终端。

![QuickDoc 自定义终端设置](./photos/新增功能自定义终端.png)

## v1.4.1 更新亮点

- 在“通用”设置页的“开机自启动”下新增“静默启动”开关
- 开启后，登录 macOS 时 QuickDoc 会直接在后台运行，不再弹出软件主界面

## v1.4.0 更新亮点

- 菜单栏图标升级为专用模板图标，可自动适配 macOS 明暗模式
- 左键和右键点击菜单栏图标都会打开快捷菜单
- 菜单栏新增“新建文件类型”和“其他功能”快捷配置，无需打开主窗口即可调整 Finder 右键菜单
- 二级菜单中的开关支持连续勾选，调整多个项目时菜单不会反复关闭
- 通用设置页新增“检查更新”，发现新版本后会先请求用户确认，再下载 ZIP 安装包、校验并在退出后覆盖旧版本，重新启动后提示更新完成

### 菜单栏快捷配置

直接从菜单栏调整 Finder 右键新建文件类型和其他快捷功能。

<p align="center">
  <img src="./photos/菜单栏界面.png" alt="QuickDoc v1.4.0 菜单栏快捷配置" width="680">
</p>

### 检查更新确认

发现新版本后，QuickDoc 会先询问用户是否下载并安装。

![QuickDoc 软件检查更新确认](./photos/软件检查更新.png)

### 更新完成提示

覆盖安装成功后，QuickDoc 会自动重新打开，并明确提示已经升级到最新版。

![QuickDoc 软件更新成功](./photos/软件更新成功.png)

## v1.3.1 更新亮点

- 修复在桌面创建文件后可能额外打开 Finder 窗口的问题
- 修复“在终端中打开”可能额外启动一个用户主目录终端窗口的问题
- 感谢 [DD-hit](https://github.com/DD-hit) 在 [#4](https://github.com/SkyImplied/QuickDoc/pull/4) 中贡献以上修复

## v1.3 更新亮点

- 新增 Finder 工具栏入口，可将 QuickDoc 添加到访达工具栏并直接调用程序
- 工具栏入口适用于本地访达、外置硬盘、云盘等所有已监控文件夹
- 扩展监控范围覆盖用户主目录、常用目录、外置卷与 iCloud Drive，解决外置硬盘和云盘无法使用的问题
- 新增完整设置应用，包含“通用”“权限与扩展”“新建文件类型”“访达操作”等页面
- 新增 4 种显示方式：仅菜单栏、同时隐藏菜单栏和 Dock、仅 Dock、菜单栏和 Dock 同时显示
- 新增开机自启动、终端直达、路径复制开关
- 新增扩展状态检测，可在应用内确认 Finder Sync 是否已启用，并一键跳转系统设置
- 新增右键菜单预览与排序编辑，设置顺序后 Finder 菜单会同步更新
- 优化 Finder 重启流程，扩展配置修改后刷新更稳定

## 为什么用 QuickDoc

- 不用打开其他应用，直接在 Finder 里右键新建常见文件
- 可以从自己的模板新建文件，常用文档样式不用每次从头整理
- 只显示你真正需要的文件类型，菜单更干净
- 支持添加自定义后缀，适配个人工作流
- 通过可视化预览调整菜单顺序，减少常用项查找成本
- 在同一个右键菜单里用选定的终端打开当前文件夹，或复制当前路径
- 从可选的“快捷操作”菜单中拷贝、粘贴或剪切 Finder 项目
- 自动避免重名，如果文件已存在会自动追加数字后缀

## 支持的新建文件类型

v1.6.0 内置支持：

- TXT
- Markdown（`.md`）
- Word（`.docx`）
- Excel（`.xlsx`）
- CSV
- PowerPoint（`.pptx`）
- JSON
- 空白文件
- Python（`.py`）
- HTML
- Shell（`.sh`）
- Rich Text（`.rtf`）

默认启用的类型为：`TXT`、`Markdown`、`Word`、`Excel`、`CSV`、`PowerPoint`、`JSON`、`空白文件`。

## 界面预览

### 通用设置

“通用”页负责管理启动行为、显示方式、“在终端中打开”“复制当前路径”等右键快捷操作、自定义终端 App，也可以检查并安装新版本。

<p align="center">
  <img src="./photos/通用设置界面1.png" alt="QuickDoc 通用设置界面" width="680">
  <img src="./photos/通用设置界面2.png" alt="QuickDoc 通用设置详情界面" width="680">
</p>

### Finder 右键菜单

扩展启用后，Finder 右键中会出现“新建文件”，并可按需显示终端直达与路径复制功能。

<p align="center">
  <img src="./photos/新版右键菜单界面.png" alt="QuickDoc Finder 右键菜单界面" width="680">
</p>

### 权限与扩展

QuickDoc 会检查 Finder Sync 扩展是否已经启用，并引导你进入正确的 macOS 设置页面。

![QuickDoc 权限与扩展界面](./photos/权限与扩展界面.png)

### 新建文件类型与文件模板

你可以勾选内置类型、添加自定义后缀、管理文件模板，并通过预览区域编辑 Finder 菜单中的显示顺序。

<p align="center">
  <img src="./photos/新建文件类型界面1.png" alt="QuickDoc 新建文件类型界面" width="680">
  <img src="./photos/新建文件类型界面2.png" alt="QuickDoc 新建文件模板界面" width="680">
</p>

### 菜单栏快捷配置

直接从菜单栏调整 Finder 右键新建文件类型和其他快捷功能。

<p align="center">
  <img src="./photos/菜单栏界面.png" alt="QuickDoc 菜单栏快捷配置" width="680">
</p>

### 自定义文件模板

按文件类型分别管理模板，控制哪些模板显示在 Finder 右键菜单中，并在 Finder 中使用模板三级菜单。

<p align="center">
  <img src="./photos/自定义文件模版.png" alt="QuickDoc 自定义文件模板" width="680">
  <img src="./photos/自定义文件模版三级菜单.png" alt="QuickDoc 自定义文件模板三级菜单" width="680">
</p>

### 访达操作

当 Finder 没有立刻刷新菜单时，可以在应用内一键重启 Finder，让扩展重新载入。

![QuickDoc 访达操作界面](./photos/访达操作界面.png)

### 关于页面

“关于”页面集中展示应用介绍、版本信息和联系入口。

![QuickDoc 关于页面](./photos/关于界面.png)

## 使用方式

1. 启动 `QuickDoc.app`
2. 打开“权限与扩展”页面，或点击 `打开扩展设置`
3. 在 macOS 的 Finder Extensions 中启用 `QuickDocFinderSync`
4. 在 Finder 的文件夹空白处、选中的文件夹上，或桌面上点击右键
5. 选择 `新建文件`，创建你需要的文件

如果你在设置中开启了相关开关，Finder 顶层右键菜单中还会额外出现 `在终端中打开`、`复制当前路径` 和 `快捷操作`。

`在终端中打开` 会使用“通用”设置页里选定的终端 App。你可以随时选择第三方终端，也可以恢复为系统终端。

## 安装方式

最简单的方式是从 GitHub Releases 下载最新的 `QuickDoc-<version>.dmg`，打开后把 `QuickDoc.app` 拖到 `Applications`。

然后：

1. 打开 `QuickDoc.app`
2. 进入 `权限与扩展` 页面，或点击 `打开扩展设置`
3. 在 `系统设置 > 隐私与安全性 > 登录项与扩展` 中启用 `QuickDocFinderSync`
4. 如果右键菜单没有马上出现，可直接使用 QuickDoc 中的 `立即重启 Finder`

安装 v1.4.0 或后续版本后，后续版本可以在“通用”页面底部点击 `检查更新`。发现新版本时，QuickDoc 会先询问是否安装；用户确认后才会自动下载安装，完成覆盖后重新打开并提示升级成功。

如果 macOS 提示应用来自未识别开发者，可以在 Finder 中按住 `Control` 点击应用，再选择 `打开`。

## 从源码编译

QuickDoc 依赖完整 Xcode，因为 Finder Sync 扩展不能只靠 Command Line Tools 构建。

### 方式一：一键本地构建并运行

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./script/build_and_run.sh
```

这个脚本会自动：

1. 构建 `QuickDoc` 主程序和 Finder 扩展
2. 刷新 Finder 扩展注册
3. 重启 Finder
4. 启动 `QuickDoc.app`

首次运行后，如果系统还没有自动启用扩展，请手动开启 `QuickDocFinderSync`。

### 方式二：使用 Xcode 手动编译

1. 如有需要，先执行一次：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

2. 使用 Xcode 打开 `QuickDoc.xcodeproj`
3. 选择 `QuickDoc` scheme
4. 点击 `Run`
5. 在 Finder Extensions 中启用 `QuickDocFinderSync`

## 从源码生成发布产物

如果你想自己生成 `.app`、`.zip` 或 `.dmg`：

```bash
./script/package_release.sh
```

生成产物会输出到 `build/release/` 目录。

## 故障排查

如果修改设置或重新编译后 Finder 菜单没有刷新，可以手动重启 Finder：

```bash
killall Finder
```

如果点击菜单没有反应，可以边操作边查看应用与扩展日志：

```bash
log stream --info --style compact --predicate 'process == "QuickDoc" OR process == "QuickDocFinderSync"'
```
