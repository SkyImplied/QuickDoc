import Foundation

var failures: [String] = []
var checks = 0

func expect(_ condition: Bool, _ message: String) {
    checks += 1
    if condition {
        return
    }
    failures.append(message)
    fputs("FAIL \(message)\n", stderr)
}

func rememberedDirectoryDuringMenuBuild(origin: FinderMenuOrigin, finderSyncPath: String?) -> String? {
    switch FinderMenuTargetPolicy.menuBuildPlan(for: origin) {
    case .deferDirectoryUntilAction:
        return nil
    case .rememberFinderSyncTarget:
        return finderSyncPath
    }
}

let home = "/Users/test"
let external = "/Volumes/Backup/Photos"
let staleSelection = ["/Users/test/Desktop/note.txt"]

@main
enum FinderMenuTargetPolicyTestRunner {
    static func main() {
        if CommandLine.arguments.contains("--print-script") {
            print(FinderMenuTargetPolicy.frontWindowScript(bundleIdentifier: "com.apple.finder"))
            return
        }


    expect(
        rememberedDirectoryDuringMenuBuild(origin: .toolbar, finderSyncPath: home) == nil,
        "工具栏组菜单时不得记下 Finder Sync 的主目录"
    )
    expect(
        rememberedDirectoryDuringMenuBuild(origin: .container, finderSyncPath: "\(home)/Desktop") == "\(home)/Desktop",
        "容器快捷菜单应记住 Finder Sync 目标"
    )
    expect(
        rememberedDirectoryDuringMenuBuild(origin: .items, finderSyncPath: "\(home)/Documents") == "\(home)/Documents",
        "项目快捷菜单应记住 Finder Sync 目标"
    )
    expect(
        FinderMenuTargetPolicy.menuBuildPlan(for: .toolbar) == .deferDirectoryUntilAction,
        "工具栏菜单构建计划必须推迟到动作执行之后"
    )

    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .directory(external)
        ) == .usePath(external),
        "工具栏应使用当前前置窗口，而不是记下的主目录"
    )
    for failure in [
        FinderFrontWindowQuery.noWindow,
        .timeout,
        .permissionDenied,
        .notADirectory,
        .failed
    ] {
        let plan = FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: failure
        )
        if case .usePath(let path) = plan {
            expect(false, "查询失败 \(failure) 时仍使用了 \(path)")
        }
    }
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .noWindow
        ) == .cancel(.noWindow),
        "没有窗口时应取消"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .timeout
        ) == .cancel(.timeout),
        "超时应取消"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .permissionDenied
        ) == .cancel(.permissionDenied),
        "没有自动化权限时应取消"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .notADirectory
        ) == .cancel(.notADirectory),
        "当前目标不是文件夹时应取消"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .toolbar,
            rememberedPath: home,
            frontWindow: .failed
        ) == .cancel(.unresolved),
        "查询失败时应取消，不得回退到主目录"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .container,
            rememberedPath: "\(home)/Desktop",
            frontWindow: .directory(external)
        ) == .usePath("\(home)/Desktop"),
        "快捷菜单不得改用另一个前置窗口"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .container,
            rememberedPath: nil,
            frontWindow: .directory(home)
        ) == .cancel(.unresolved),
        "快捷菜单没有记住目标时不得改落到主目录"
    )

    expect(
        FinderMenuTargetPolicy.selectionForAction(
            origin: .toolbar,
            rememberedPaths: staleSelection,
            liveSelection: .permissionDenied,
            directory: .permissionDenied,
            currentDirectoryPath: home
        ) == .cancel(.permissionDenied),
        "工具栏选择查询失败时不得使用过期选择"
    )
    expect(
        FinderMenuTargetPolicy.selectionForAction(
            origin: .toolbar,
            rememberedPaths: staleSelection,
            liveSelection: .timeout,
            directory: .timeout,
            currentDirectoryPath: home
        ) == .cancel(.timeout),
        "工具栏选择超时时不得使用过期选择"
    )
    expect(
        FinderMenuTargetPolicy.selectionForAction(
            origin: .toolbar,
            rememberedPaths: [],
            liveSelection: .paths([external, "\(external)/a.txt"]),
            directory: .directory(external),
            currentDirectoryPath: external
        ) == .usePaths(["\(external)/a.txt"]),
        "工具栏选择应去掉被当成选中项的当前目录"
    )
    expect(
        FinderMenuTargetPolicy.selectionForAction(
            origin: .items,
            rememberedPaths: staleSelection,
            liveSelection: .timeout,
            directory: .directory(external),
            currentDirectoryPath: external
        ) == .usePaths(staleSelection),
        "项目快捷菜单应使用组菜单时记下的选择"
    )
    expect(
        FinderMenuTargetPolicy.selectionForAction(
            origin: .toolbar,
            rememberedPaths: [],
            liveSelection: .paths(["\(home)/Desktop/a.txt"]),
            directory: .noWindow,
            currentDirectoryPath: nil
        ) == .cancel(.noWindow),
        "没有窗口时不得改用桌面选择"
    )

    expect(
        FinderMenuTargetPolicy.pathCopyPlan(
            selection: .cancel(.timeout),
            directory: .usePath(home)
        ) == .cancel(.timeout),
        "选择查询失败时不得改复制主目录路径"
    )
    expect(
        FinderMenuTargetPolicy.pathCopyPlan(
            selection: .usePaths([]),
            directory: .usePath(external)
        ) == .copyPath(external),
        "没有选中项时应复制当前目录"
    )
    expect(
        FinderMenuTargetPolicy.pathCopyPlan(
            selection: .usePaths(["\(external)/a.txt"]),
            directory: .usePath(external)
        ) == .copyPath("\(external)/a.txt"),
        "有选中项时应复制该项路径"
    )
    expect(
        FinderMenuTargetPolicy.pathCopyPlan(
            selection: .usePaths([]),
            directory: .cancel(.noWindow)
        ) == .cancel(.noWindow),
        "没有选中项且没有窗口时复制路径应取消"
    )

    expect(
        FinderMenuTargetPolicy.selectionActionsEnabled(origin: .toolbar, finderSyncSelectionCount: 0),
        "工具栏在 Finder Sync 看不到选择时仍应允许稍后解析"
    )
    expect(
        !FinderMenuTargetPolicy.selectionActionsEnabled(origin: .items, finderSyncSelectionCount: 0),
        "项目菜单没有选择时应禁用"
    )
    expect(
        FinderMenuTargetPolicy.selectionActionsEnabled(origin: .items, finderSyncSelectionCount: 2),
        "项目菜单有选择时应启用"
    )
    expect(
        !FinderMenuTargetPolicy.selectionActionsEnabled(origin: .container, finderSyncSelectionCount: 3),
        "空白处快捷菜单不应把容器当成已选文件"
    )

    expect(
        FinderMenuTargetPolicy.monitoredRootsExcludeProtectedMounts(
            homePath: home,
            volumeMounts: ["/Volumes/Backup", "/Volumes/Backup/Photos"]
        ),
        "监视根只能是主目录和 /Volumes，不能包含外置磁盘挂载点"
    )
    expect(
        !FinderMenuTargetPolicy.isSidebarProtectedVolumeMount("/Volumes"),
        "/Volumes 本身不是要保护图标的挂载点"
    )
    expect(
        !FinderMenuTargetPolicy.isSidebarProtectedVolumeMount(home),
        "主目录不是外置磁盘挂载点"
    )
    expect(
        FinderMenuTargetPolicy.monitoredRootPaths(homePath: home) == [home, "/Volumes"],
        "监视根路径应保持为主目录和 /Volumes"
    )

    expect(FinderMenuTargetPolicy.transportFailure(number: -1712).0 == .timeout, "errAETimeout 应归为超时")
    expect(FinderMenuTargetPolicy.transportFailure(number: -1743).0 == .permissionDenied, "-1743 应归为没有权限")
    expect(FinderMenuTargetPolicy.transportFailure(number: -1744).1 == .permissionDenied, "-1744 应归为没有权限")
    expect(FinderMenuTargetPolicy.transportFailure(number: -1700).0 == .failed, "其他 AppleEvent 错误应归为失败")
    expect(FinderMenuTargetPolicy.transportFailure(number: nil).1 == .failed, "缺少错误码应归为失败")

    expect(
        FinderMenuTargetPolicy.directoryQuery(state: .noWindow, pathIsDirectory: false) == .noWindow,
        "无窗口状态应保留"
    )
    expect(
        FinderMenuTargetPolicy.directoryQuery(state: .unavailable, pathIsDirectory: false) == .notADirectory,
        "有窗口但目标不可用时不得当成主目录"
    )
    expect(
        FinderMenuTargetPolicy.directoryQuery(state: .path(external), pathIsDirectory: true) == .directory(external),
        "可用目录路径应被接受"
    )
    expect(
        FinderMenuTargetPolicy.directoryQuery(state: .path("/Volumes/Backup/file.txt"), pathIsDirectory: false) == .notADirectory,
        "文件目标不得当成可写目录"
    )

    let script = FinderMenuTargetPolicy.frontWindowScript(bundleIdentifier: "com.apple.finder")
    expect(script.contains("with timeout of 2 seconds"), "脚本必须带 2 秒超时")
    expect(script.contains("tell application id \"com.apple.finder\""), "脚本必须发给 Finder")
    expect(script.contains("target of front Finder window"), "脚本必须读取前置窗口目标")
    expect(script.contains("directoryState"), "脚本必须区分无窗口和目标不可用")
    expect(script.contains("if errNum is -1712 then error number errNum"), "超时必须继续向外抛出")
    expect(!script.contains(home), "脚本不得写死主目录")

    let messages = [
        FinderMenuTargetPolicy.userMessage(for: .noWindow, action: "新建文件"),
        FinderMenuTargetPolicy.userMessage(for: .timeout, action: "新建文件"),
        FinderMenuTargetPolicy.userMessage(for: .permissionDenied, action: "粘贴"),
        FinderMenuTargetPolicy.userMessage(for: .notADirectory, action: "打开终端"),
        FinderMenuTargetPolicy.userMessage(for: .unresolved, action: "复制路径")
    ]
    expect(messages.allSatisfy { !$0.contains(home) && !$0.contains("/Volumes") }, "失败提示不得带一个猜测出来的目录")

    if !failures.isEmpty {
        fputs("\(failures.count) failed\n", stderr)
        exit(1)
    }
    print("PASS \(checks) finder menu target policy checks")
    }
}
