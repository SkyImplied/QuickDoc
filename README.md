# QuickDoc

[中文说明](README.zh-CN.md)

QuickDoc is a macOS Finder Sync extension that adds a fast "New File" menu to Finder, so you can create common documents directly from a folder background, a selected folder, or the Desktop.

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

The recommended way to use QuickDoc is to download the latest `QuickDoc-<version>.dmg` from GitHub Releases, open it, and drag `QuickDoc.app` into `Applications`.

Then:

1. Open `QuickDoc.app`
2. Click `打开扩展设置`
3. Enable `QuickDocFinderSync` in Finder Extensions
4. Restart Finder if the context menu does not appear immediately

If macOS warns that the app is from an unidentified developer, open it once from Finder with `Control` + click -> `Open`.

## Build From Source

QuickDoc requires full Xcode because Finder Sync extensions cannot be built with Command Line Tools alone.

### Option 1: one-command local build and run

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./script/build_and_run.sh
```

This script will:

1. Build the `QuickDoc` app and Finder extension
2. Refresh Finder extension registration
3. Restart Finder
4. Launch `QuickDoc.app`

After the first launch, enable `QuickDocFinderSync` in Finder Extensions if macOS has not already enabled it.

### Option 2: build manually in Xcode

1. Run the following once if needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

2. Open `QuickDoc.xcodeproj` in Xcode
3. Select the `QuickDoc` scheme
4. Click Run
5. Enable `QuickDocFinderSync` in Finder Extensions

## Build Distribution Files

If you want to build your own app bundle, ZIP, or DMG from source:

```bash
./script/package_release.sh
```

Artifacts are generated in `dist/`.

## Troubleshooting

If Finder does not refresh the menu after code changes, restart Finder:

```bash
killall Finder
```

If a menu click does nothing, stream extension logs while testing:

```bash
log stream --info --style compact --predicate 'process == "QuickDoc" OR process == "QuickDocFinderSync"'
```
