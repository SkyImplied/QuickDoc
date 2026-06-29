# QuickDoc 项目规则

## 构建产物

- 开发、调试阶段产生的软件大包和编译结果统一放在 `build/`。
- 构建完成后只保留可运行的编译结果，例如 `build/Debug/QuickDoc.app`。
- Xcode DerivedData、中间文件、预编译头、安装暂存目录、临时目标产物等编译中间产物必须在构建成功后删除。
- `build/` 里的生成内容不提交到仓库。

## 发布产物

- 只有确认可以发布的最终成品才放在 `dist/`。
- 待发布的 `.dmg` 和 `.zip` 包统一输出到 `dist/`。
- 发布打包过程中的临时暂存和中间产物可临时放在 `build/release/`，打包成功后必须删除。
- 开发调试构建不能输出到 `dist/`。

## 常用命令

- 开发构建：

```sh
./script/build_and_run.sh build
```

- 清理开发构建产物：

```sh
./script/build_and_run.sh clean
```

- 生成发布包：

```sh
./script/package_release.sh
```
