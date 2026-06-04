# QuickDoc v1.5.5

QuickDoc v1.5.5 refines Finder path copying and separates the related General settings so terminal shortcuts and path-copy behavior are easier to understand.

## Highlights

- `Copy Current Path` now follows the current Finder selection.
- When no file or folder is selected, path copy keeps the previous behavior and copies the current Finder folder path.
- When a file or folder is selected, path copy now copies the selected item's full path instead of its parent folder.
- Split `Open in Terminal` and `Copy Current Path` into separate General settings sections.
- Added clearer General settings copy explaining the folder-vs-selected-item path-copy behavior.

## 中文说明

- “复制当前路径”现在会根据 Finder 当前选择决定复制内容。
- 未选中文件或文件夹时，继续复制当前 Finder 文件夹路径。
- 选中文件或文件夹时，复制所选项目的完整路径，不再只复制父文件夹路径。
- “通用设置”中已将“终端直达”和“路径复制”拆分为两个独立板块。
- 路径复制下方新增更清晰的规则说明，便于启用前确认行为。

## Downloads

- `QuickDoc-1.5.5.dmg`: recommended installer for manual installation.
- `QuickDoc-1.5.5.zip`: update package used by the in-app updater.

> Note: this release follows the current project signing workflow. If macOS warns that the app is from an unidentified developer, use Control-click > Open for the initial launch.
