# QuickDoc

[English README](README.md)

QuickDoc 是一个围绕 macOS Finder Sync 扩展构建的效率工具。它会在 Finder 右键菜单中加入一个实用的“新建文件”子菜单，而在 v1.1 中，它还补齐了完整设置界面，用来管理显示方式、扩展状态、菜单排序，以及 Finder 快捷操作。

## v1.1 更新亮点

- 新增完整设置应用，包含“通用”“权限与扩展”“新建文件类型”“访达操作”等页面
- 新增 4 种显示方式：仅菜单栏、同时隐藏菜单栏和 Dock、仅 Dock、菜单栏和 Dock 同时显示
- 新增开机自启动、终端直达、路径复制开关
- 新增扩展状态检测，可在应用内确认 Finder Sync 是否已启用，并一键跳转系统设置
- 新增右键菜单预览与排序编辑，设置顺序后 Finder 菜单会同步更新
- 优化 Finder 重启流程，扩展配置修改后刷新更稳定

## 为什么用 QuickDoc

- 不用打开其他应用，直接在 Finder 里右键新建常见文件
- 只显示你真正需要的文件类型，菜单更干净
- 支持添加自定义后缀，适配个人工作流
- 通过可视化预览调整菜单顺序，减少常用项查找成本
- 在同一个右键菜单里直接打开终端或复制当前路径
- 自动避免重名，如果文件已存在会自动追加数字后缀

## 支持的新建文件类型

v1.1 内置支持：

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

### 菜单栏控制

点击状态栏图标后，可以快速打开设置、切换显示方式、控制开机自启动、重启访达，或跳转扩展设置。

![QuickDoc 菜单栏界面](./photos/菜单栏界面.png)

### 通用设置

“通用”页负责管理启动行为、显示方式，以及“在终端中打开”“复制当前路径”等右键快捷操作。

![QuickDoc 通用设置界面](./photos/通用设置界面.png)

### Finder 右键菜单

扩展启用后，Finder 右键中会出现“新建文件”，并可按需显示终端直达与路径复制功能。

![QuickDoc Finder 右键菜单界面](./photos/右键菜单界面.png)

### 权限与扩展

QuickDoc 会检查 Finder Sync 扩展是否已经启用，并引导你进入正确的 macOS 设置页面。

![QuickDoc 权限与扩展界面](./photos/权限与扩展界面.png)

### 新建文件类型与菜单预览

你可以勾选内置类型、添加自定义后缀，并通过预览区域编辑 Finder 菜单中的显示顺序。

![QuickDoc 新建文件类型界面](./photos/新建文件类型界面.png)

### 访达操作

当 Finder 没有立刻刷新菜单时，可以在应用内一键重启 Finder，让扩展重新载入。

![QuickDoc 访达操作界面](./photos/访达操作界面.png)

## 使用方式

1. 启动 `QuickDoc.app`
2. 打开“权限与扩展”页面，或点击 `打开扩展设置`
3. 在 macOS 的 Finder Extensions 中启用 `QuickDocFinderSync`
4. 在 Finder 的文件夹空白处、选中的文件夹上，或桌面上点击右键
5. 选择 `新建文件`，创建你需要的文件

如果你在设置中开启了相关开关，Finder 顶层右键菜单中还会额外出现 `在终端中打开` 和 `复制当前路径`。

## 安装方式

最简单的方式是从 GitHub Releases 下载最新的 `QuickDoc-<version>.dmg`，打开后把 `QuickDoc.app` 拖到 `Applications`。

然后：

1. 打开 `QuickDoc.app`
2. 进入 `权限与扩展` 页面，或点击 `打开扩展设置`
3. 在 `系统设置 > 隐私与安全性 > 登录项与扩展` 中启用 `QuickDocFinderSync`
4. 如果右键菜单没有马上出现，可直接使用 QuickDoc 中的 `立即重启 Finder`

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

生成产物会输出到 `dist/` 目录。

## 故障排查

如果修改设置或重新编译后 Finder 菜单没有刷新，可以手动重启 Finder：

```bash
killall Finder
```

如果点击菜单没有反应，可以边操作边查看应用与扩展日志：

```bash
log stream --info --style compact --predicate 'process == "QuickDoc" OR process == "QuickDocFinderSync"'
```
