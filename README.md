<div align="center">
  <img src="./logo_dark.png" alt="QuickDoc logo" width="112">
  <h1>QuickDoc</h1>
  <p>Create common files directly from Finder's right-click menu and toolbar.</p>
  <p>
    <a href="https://github.com/SkyImplied/QuickDoc/releases/tag/v1.6.1"><img src="https://img.shields.io/badge/version-v1.6.1-blue" alt="Version v1.6.1"></a>
    <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?logo=apple" alt="Platform macOS 13+">
    <img src="https://img.shields.io/badge/built%20with-Swift-F05138?logo=swift&logoColor=white" alt="Built with Swift">
    <a href="https://github.com/SkyImplied/QuickDoc/releases/download/v1.6.1/QuickDoc-1.6.1.dmg"><img src="https://img.shields.io/badge/download-DMG-brightgreen?logo=apple&logoColor=white" alt="Download DMG"></a>
    <a href="https://github.com/SkyImplied/QuickDoc/releases"><img src="https://img.shields.io/github/downloads/SkyImplied/QuickDoc/total?label=downloads" alt="Downloads"></a>
  </p>
  <p>
    English | <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.ja.md">日本語</a>
  </p>
</div>

QuickDoc is a macOS utility built around a Finder Sync extension. It adds a practical `New File` submenu to Finder's context menu, and since v1.3 it also supports adding QuickDoc to the Finder toolbar so file creation can be invoked directly from the toolbar.

## What's New in v1.6.1

- Fixed a bug where `Open in Terminal` could sometimes open the main QuickDoc app window and show its Dock icon.
- Fixed abnormal app logo sizing for some users.

## What's New in v1.6.0

- Fixed copy and cut actions when invoking QuickDoc from the Finder toolbar in cloud drive and external drive folders.
- Added Finder right-click menu support for external drives. Older versions only supported external drive access through the toolbar. Due to Apple platform restrictions, cloud drive folders do not yet support direct right-click invocation; please continue using the toolbar there.
- Improved the DMG installation window with a cleaner drag-to-install layout.

### External Drive Right-Click Menu

<p align="center">
  <img src="./photos/支持外置硬盘访达调用右键菜单功能.png" alt="QuickDoc Finder right-click menu on external drives" width="680">
</p>

### Improved DMG Installer

<p align="center">
  <img src="./photos/改进的dmg安装界面.png" alt="QuickDoc improved DMG installer" width="680">
</p>

## What's New in v1.5.5

- `Copy Current Path` now follows the current Finder selection: with nothing selected it copies the current folder path, and with a file or folder selected it copies that selected item's full path.
- Split `Open in Terminal` and `Copy Current Path` into separate General settings sections, making terminal selection and path-copy behavior easier to scan.
- Refined the path-copy description in General settings so the folder-vs-selected-item behavior is clear before enabling it.

## What's New in v1.5.4

- Added custom file templates for enabled file types, so Word, Excel, PowerPoint, TXT, and custom extensions can create files from user-provided templates instead of only blank defaults.
- Added a dedicated template manager that separates templates by file type and supports custom display names, visibility toggles, ordering, renaming, and deletion.
- Finder's `New File` menu now expands into a third-level template menu when a file type has visible templates, with `Blank default document` kept as the first option.
- Custom file types now use the unified blank-file icon, and the template manager only shows file types that are enabled in the main new-file settings.

### Custom file templates

Upload your own template documents, choose the menu name, and decide whether each template should appear in Finder.

![QuickDoc custom file templates](./photos/自定义文件模版.png)

When templates are visible for a file type, Finder shows them in a third-level menu under that type.

![QuickDoc custom template submenu](./photos/自定义文件模版三级菜单.png)

## What's New in v1.5.2

- Fixed several known issues
- Refined the app experience and refreshed the About page with the latest feature overview and contact information
- Improved the DMG installation flow with clearer drag guidance, larger icons, centered content, and sharper Retina installation text

## What's New in v1.5.1

- Fixed an issue where PowerPoint could report newly created `.pptx` files as having problematic content and ask to repair them
- Updated the built-in blank PPTX template with the standard masters, layouts, theme, document properties, and relationships expected by PowerPoint

## What's New in v1.5.0

- Added custom terminal app support for `Open in Terminal`, so users can choose third-party terminals instead of being limited to macOS Terminal
- The General settings page now shows the selected terminal app with its icon, name, and path, plus direct actions to change it or restore the system Terminal
- Refactored the built-in file type icons with a more unified visual style

### Custom terminal app

Choose your preferred terminal app from General settings. QuickDoc will use that app when opening the current Finder folder from the right-click menu.

![QuickDoc custom terminal app setting](./photos/新增功能自定义终端.png)

## What's New in v1.4.1

- Added a `Silent Launch` option beneath `Launch at Login` in General settings
- When enabled, QuickDoc starts in the background after macOS login without opening the main window

## What's New in v1.4.0

- Added a dedicated template menu bar icon with automatic light and dark mode adaptation
- Both left-click and right-click now open the menu bar shortcut menu
- Added menu bar shortcuts for configuring new file types and optional Finder actions without opening the main window
- Secondary menu toggles stay open so multiple settings can be changed in one pass
- Added an in-app update checker that asks for confirmation before downloading a new version, validates the ZIP package, replaces the previous app after quitting, relaunches QuickDoc, and confirms when the upgrade is complete

### Menu bar shortcuts

Configure Finder new-file types and optional quick actions directly from the menu bar.

<p align="center">
  <img src="./photos/菜单栏界面.png" alt="QuickDoc v1.4.0 menu bar shortcuts" width="680">
</p>

### Update confirmation

When a newer version is available, QuickDoc asks for confirmation before downloading and installing it.

![QuickDoc software update confirmation](./photos/软件检查更新.png)

### Update complete

After replacement succeeds, QuickDoc relaunches automatically and confirms that the upgrade is complete.

![QuickDoc software update completed](./photos/软件更新成功.png)

## What's New in v1.3.1

- Fixed an issue where creating a file on the Desktop could open an unwanted Finder window
- Fixed an issue where `Open in Terminal` could launch an extra terminal window in the home directory
- Thanks to [DD-hit](https://github.com/DD-hit) for contributing these fixes in [#4](https://github.com/SkyImplied/QuickDoc/pull/4)

## What's New in v1.3

- Added a Finder toolbar entry so QuickDoc can be added to Finder's toolbar and invoked directly
- Finder toolbar support works across local Finder folders, external drives, cloud drive folders, and other monitored locations
- Expanded Finder Sync monitoring to user folders, common directories, external volumes, and iCloud Drive, fixing previous external-drive and cloud-drive coverage gaps
- Added a redesigned settings app with pages for `General`, `Permissions & Extensions`, `New File Types`, and `Finder Actions`
- Added four app display modes: menu bar only, hidden in both menu bar and Dock, Dock only, and menu bar + Dock
- Added launch at login, `Open in Terminal`, and `Copy Current Path` toggles
- Added in-app Finder Sync status confirmation with a direct shortcut to system settings
- Added menu preview and ordering controls so the Finder right-click menu stays in sync with your chosen order
- Improved Finder restart flow so extension refresh is more reliable after configuration changes

## Why QuickDoc

- Create common files directly from Finder without opening another app
- Create files from your own templates instead of rebuilding the same document styles by hand
- Show only the file types you actually use
- Add custom extensions for your own workflow
- Keep the context menu organized with visual ordering controls
- Open the current folder in your selected terminal app or copy its path from the same right-click menu
- Copy, paste, or cut Finder items from the optional Quick Actions submenu
- Avoid overwriting files by automatically appending numeric suffixes when names already exist

## Supported File Types

Built-in file types in v1.6.1:

- TXT
- Markdown (`.md`)
- Word (`.docx`)
- Excel (`.xlsx`)
- CSV
- PowerPoint (`.pptx`)
- JSON
- Blank file
- Python (`.py`)
- HTML
- Shell (`.sh`)
- Rich Text (`.rtf`)

Default-enabled types are `TXT`, `Markdown`, `Word`, `Excel`, `CSV`, `PowerPoint`, `JSON`, and `Blank file`.

## Screenshots

### General settings

The general page manages launch behavior, display mode, right-click quick actions such as `Open in Terminal` and `Copy Current Path`, custom terminal app selection, and in-app update checks.

<p align="center">
  <img src="./photos/通用设置界面1.png" alt="QuickDoc general settings" width="680">
  <img src="./photos/通用设置界面2.png" alt="QuickDoc general settings details" width="680">
</p>

### Finder context menu

After the extension is enabled, `New File` appears in Finder together with optional quick actions.

<p align="center">
  <img src="./photos/新版右键菜单界面.png" alt="QuickDoc Finder context menu" width="680">
</p>

### Permissions and extensions

QuickDoc can verify whether the Finder Sync extension is enabled and guide you to the correct macOS settings page.

![QuickDoc permissions and extensions](./photos/权限与扩展界面.png)

### New file types and templates

Enable or disable built-in file types, add custom extensions, manage templates, and edit the menu order from the preview area.

<p align="center">
  <img src="./photos/新建文件类型界面1.png" alt="QuickDoc new file types" width="680">
  <img src="./photos/新建文件类型界面2.png" alt="QuickDoc new file templates" width="680">
</p>

### Menu bar shortcuts

Configure Finder new-file types and optional quick actions directly from the menu bar.

<p align="center">
  <img src="./photos/菜单栏界面.png" alt="QuickDoc menu bar shortcuts" width="680">
</p>

### Custom file templates

Manage templates by file type, control which templates are visible in Finder, and use template submenus from Finder.

<p align="center">
  <img src="./photos/自定义文件模版.png" alt="QuickDoc custom file templates" width="680">
  <img src="./photos/自定义文件模版三级菜单.png" alt="QuickDoc custom template submenu" width="680">
</p>

### Finder actions

If Finder does not refresh immediately, QuickDoc provides a one-click restart action to reload the extension.

![QuickDoc Finder actions](./photos/访达操作界面.png)

### About

The About page collects the app overview, version, and contact entry points.

![QuickDoc About page](./photos/关于界面.png)

## How It Works

1. Launch `QuickDoc.app`
2. Open the `Permissions & Extensions` page or use `Open Extension Settings`
3. Enable `QuickDocFinderSync` in macOS Finder Extensions
4. Right-click a folder background, selected folder, or the Desktop in Finder
5. Choose `新建文件` and create the file you want

If enabled in settings, `在终端中打开`, `复制当前路径`, and `快捷操作` will also appear in the top-level Finder context menu.

`在终端中打开` uses the terminal app selected in General settings. You can choose a third-party terminal app or restore the system Terminal at any time.

## Installation

The simplest way is to download the latest `QuickDoc-<version>.dmg` from GitHub Releases, open it, and drag `QuickDoc.app` into `Applications`.

Then:

1. Open `QuickDoc.app`
2. Go to `权限与扩展` or click `打开扩展设置`
3. Enable `QuickDocFinderSync` in `System Settings > Privacy & Security > Login Items & Extensions`
4. If the menu does not appear right away, use QuickDoc's `立即重启 Finder` action

After installing v1.4.0 or later, future versions can be checked from the `检查更新` button at the bottom of the General page. QuickDoc asks for confirmation before downloading an available update, then relaunches automatically and confirms when the upgrade is complete.

If macOS warns that the app is from an unidentified developer, open it once from Finder with `Control` + click and choose `Open`.

## Build From Source

QuickDoc requires full Xcode because Finder Sync extensions cannot be built with Command Line Tools alone.

### Option 1: build and run locally with one command

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./script/build_and_run.sh
```

This script will:

1. Build the `QuickDoc` app and Finder extension
2. Refresh Finder extension registration
3. Restart Finder
4. Launch `QuickDoc.app`

After the first launch, enable `QuickDocFinderSync` manually if macOS has not enabled it yet.

### Option 2: build manually in Xcode

1. Run this once if needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

2. Open `QuickDoc.xcodeproj` in Xcode
3. Select the `QuickDoc` scheme
4. Click `Run`
5. Enable `QuickDocFinderSync` in Finder Extensions

## Build Release Artifacts

To package your own `.app`, `.zip`, or `.dmg` from source:

```bash
./script/package_release.sh
```

Artifacts will be generated in `build/release/`.

## Troubleshooting

If Finder does not refresh after changing settings or rebuilding, restart Finder:

```bash
killall Finder
```

If a menu click does nothing, stream app and extension logs while testing:

```bash
log stream --info --style compact --predicate 'process == "QuickDoc" OR process == "QuickDocFinderSync"'
```
