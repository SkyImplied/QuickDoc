# QuickDoc

[中文说明](README.zh-CN.md)

QuickDoc is a macOS Finder Sync extension that adds a fast "New File" menu to Finder, so you can create common documents directly from a folder background, a selected folder, or the Desktop.

## Preview

### Light mode app interface

![QuickDoc light mode](./浅色模式app主界面.png)

### Dark mode app interface

![QuickDoc dark mode](./深色模式app主界面.png)

### Finder right-click menu

![QuickDoc Finder context menu](./菜单右键.png)

## Highlights

- Create common files directly from Finder right-click menus
- Built-in support for TXT, Markdown, Word, Excel, PowerPoint, CSV, JSON, blank files, Python, HTML, Shell, and RTF
- Toggle visible file types from the app
- Add custom file extensions for your own workflow
- Works with both light mode and dark mode
- Avoids overwriting existing files by automatically appending numeric suffixes

## How It Works

1. Launch `QuickDoc.app`
2. Enable `QuickDocFinderSync` in Finder Extensions
3. Right-click in Finder and choose `新建文件`
4. Pick the file type you want to create

## Installation

Download the latest `QuickDoc-<version>.dmg` from GitHub Releases, open it, and drag `QuickDoc.app` into `Applications`.

Then:

1. Open `QuickDoc.app`
2. Click `打开扩展设置`
3. Enable `QuickDocFinderSync` in Finder Extensions
4. Restart Finder if the context menu does not appear immediately

If macOS warns that the app is from an unidentified developer, open it once from Finder with `Control` + click -> `Open`.

## Development

This project requires full Xcode because Finder Sync extensions cannot be built with Command Line Tools alone.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then open `QuickDoc.xcodeproj` in Xcode, select the `QuickDoc` scheme, and run the app.

## Release Notes

This project currently produces an unsigned Release artifact by default. It is suitable for internal sharing or manual distribution, but Gatekeeper warnings are expected on other Macs until the app is signed with a Developer ID Application certificate and notarized by Apple.

## Troubleshooting

If Finder does not refresh the menu after code changes, restart Finder:

```bash
killall Finder
```

If a menu click does nothing, stream extension logs while testing:

```bash
log stream --info --style compact --predicate 'subsystem == "com.skyimplied.QuickDoc"'
```
