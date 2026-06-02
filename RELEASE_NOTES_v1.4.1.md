# QuickDoc v1.4.1

QuickDoc v1.4.1 adds silent launch support for a cleaner macOS login experience.

## Highlights

- Added a `Silent Launch` option beneath `Launch at Login` in General settings.
- When enabled, QuickDoc starts in the background after macOS login without opening the main window.
- Manual launches still open the settings window normally, even when silent launch is enabled.
- Migrated launch-at-login handling to a dedicated embedded login item for reliable startup behavior.

## 中文说明

- 在“通用”设置页的“开机自启动”下新增“静默启动”开关。
- 开启后，登录 macOS 时 QuickDoc 会直接在后台运行，不再弹出软件主界面。
- 即使启用了静默启动，用户手动打开 QuickDoc 时仍会正常显示设置窗口。
- 开机启动改为使用内嵌登录助手，提升 macOS 登录启动行为的可靠性。

## Downloads

- `QuickDoc-1.4.1.dmg`: recommended installer for manual installation.
- `QuickDoc-1.4.1.zip`: update package used by the in-app updater.

> Note: this release follows the current project signing workflow. If macOS warns that the app is from an unidentified developer, use Control-click > Open for the initial launch.
