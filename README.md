# QuickDoc

QuickDoc is a macOS Finder Sync extension that adds a right-click menu for creating common files in Finder folders and on the Desktop.

## Features

- New TXT document
- New Markdown document
- New Word document
- New Excel spreadsheet
- New PowerPoint presentation
- New CSV file
- New JSON file
- New blank file
- Creates inside the selected folder, the current Finder folder, or the Desktop
- Avoids overwriting existing files by appending a numeric suffix

This local development build uses a temporary sandbox exception for `/Users/` and `/Volumes/` so the Finder extension can create files from a right-click menu. A Mac App Store build would need a different permission design.

## Installation

### End users

Download the latest `QuickDoc-<version>.dmg` from GitHub Releases, open it, and drag `QuickDoc.app` into `Applications`.

Then:

1. Open `QuickDoc.app`.
2. Click `打开扩展设置`.
3. Enable `QuickDocFinderSync` in Finder Extensions.
4. Restart Finder if the context menu does not appear immediately.

If macOS warns that the app is from an unidentified developer, open it once from Finder with `Control` + click -> `Open`. A fully signed and notarized release requires a Developer ID certificate.

## Build and Run

This project requires full Xcode because Finder Sync extensions cannot be built with Command Line Tools alone.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./script/build_and_run.sh
```

Then enable the extension:

1. Open QuickDoc.
2. Click `打开扩展设置`.
3. Enable `QuickDocFinderSync` in Finder Extensions.
4. Restart Finder if the context menu does not appear immediately.

## Build a Release DMG

To build a distributable app bundle and DMG locally:

```bash
./script/package_release.sh
```

Artifacts are written to:

- `dist/QuickDoc.app`
- `dist/QuickDoc-1.0.dmg`
- `dist/QuickDoc-1.0.zip`

This packaging flow builds an unsigned Release artifact by default. It is suitable for internal sharing or manual distribution, but Gatekeeper warnings are expected on other Macs until the app is signed with a Developer ID Application certificate and notarized by Apple.

## Publish to GitHub

Recommended release flow:

1. Create a GitHub repository.
2. Add it as `origin`.
3. Commit and push this project.
4. Run `./script/package_release.sh`.
5. Upload the generated DMG and ZIP to a GitHub Release.

If you later configure `gh` and a remote repository, the remaining git push and release upload steps can be automated.

## Context Menu

Right-click a folder, a Finder window background, or the Desktop and choose `新建文件`.

## Troubleshooting

After changing the extension code, rebuild and restart Finder so macOS unloads the old extension process:

```bash
./script/build_and_run.sh
killall Finder
```

If a menu click does nothing, stream extension logs while clicking the menu:

```bash
log stream --info --style compact --predicate 'subsystem == "com.skyimplied.QuickDoc"'
```
