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

func directAppleLanguages(_ domain: String) -> [String] {
    let value = CFPreferencesCopyValue(
        "AppleLanguages" as CFString,
        domain as CFString,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    )
    return value as? [String] ?? []
}

func runIsolatedLanguageChoiceTests() {
    let domain = "com.skyimplied.QuickDoc.localization-test.\(UUID().uuidString)"
    let realDomains = [
        QuickDocLocalization.hostBundleIdentifier,
        QuickDocLocalization.extensionBundleIdentifier,
        QuickDocLocalization.loginItemBundleIdentifier
    ]
    precondition(!realDomains.contains(domain))
    let savedPreview = QuickDocLocalization.previewOverride
    let realChoices = realDomains.map { directAppleLanguages($0) }
    defer {
        QuickDocLocalization.clearIsolatedPreferencesDomainForTesting()
        QuickDocLocalization.previewOverride = savedPreview
        for (domain, choice) in zip(realDomains, realChoices) {
            expect(directAppleLanguages(domain) == choice, "隔离测试不得改写用户的语言选择")
        }
    }

    QuickDocLocalization.previewOverride = nil
    QuickDocLocalization.useIsolatedPreferencesDomainForTesting(domain)
    let inherited = CFPreferencesCopyAppValue("AppleLanguages" as CFString, domain as CFString) as? [String] ?? []
    expect(!inherited.isEmpty, "空白应用域通过 CopyAppValue 会继承系统语言列表")
    expect(directAppleLanguages(domain).isEmpty, "空白应用域本身没有语言选择")
    QuickDocLocalization.reloadStoredChoiceForTesting()
    expect(QuickDocLocalization.explicitChoice() == nil, "继承到的系统语言列表不能当作显式选择")
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hans-HK", "en-US", "zh-Hant-HK"]) == "zh-Hans",
        "跟随系统时简体香港应优先于后面的繁体"
    )
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hant-HK", "zh-Hans-CN"]) == "zh-Hant",
        "跟随系统时排在前面的繁体应生效"
    )
    if let first = Locale.preferredLanguages.first, QuickDocLocalization.code(matching: first) == "zh-Hans" {
        expect(QuickDocLocalization.resolvedCode() == "zh-Hans", "当前系统首选是简体时，跟随系统不得变成繁体")
    }

    CFPreferencesSetAppValue(
        "AppleLanguages" as CFString,
        ["zh-Hans-HK", "en-US", "zh-Hant-HK"] as CFArray,
        domain as CFString
    )
    CFPreferencesAppSynchronize(domain as CFString)
    QuickDocLocalization.reloadStoredChoiceForTesting()
    expect(QuickDocLocalization.explicitChoice() == "zh-Hans", "应用域里的 zh-Hans-HK 是显式简体选择")
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hant-TW", "zh-Hans-CN"]) == "zh-Hans",
        "显式简体选择优先于系统繁体"
    )

    CFPreferencesSetAppValue(
        "AppleLanguages" as CFString,
        ["zh-Hant-HK", "zh-Hans-HK"] as CFArray,
        domain as CFString
    )
    CFPreferencesAppSynchronize(domain as CFString)
    QuickDocLocalization.reloadStoredChoiceForTesting()
    expect(QuickDocLocalization.explicitChoice() == "zh-Hant", "应用域里的 zh-Hant-HK 是显式繁体选择")
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hans-HK", "zh-Hant-HK"]) == "zh-Hant",
        "显式繁体选择优先于系统简体"
    )

    QuickDocLocalization.select("ja")
    QuickDocLocalization.reloadStoredChoiceForTesting()
    expect(QuickDocLocalization.explicitChoice() == "ja", "软件内选择日文后应保留该选择")
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hans-HK"]) == "ja",
        "软件内选择优先于跟随系统"
    )

    QuickDocLocalization.select(nil)
    QuickDocLocalization.reloadStoredChoiceForTesting()
    expect(directAppleLanguages(domain).isEmpty, "选择跟随系统后应删除应用域语言键")
    expect(QuickDocLocalization.explicitChoice() == nil, "删除选择后不再有显式语言")
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hans-HK", "zh-Hant-HK"]) == "zh-Hans",
        "删除选择后重新跟随系统，简体在前应使用简体"
    )
    expect(
        QuickDocLocalization.resolvedCode(preferredLanguages: ["zh-Hant-TW", "zh-Hans-CN"]) == "zh-Hant",
        "删除选择后重新跟随系统，繁体在前应使用繁体"
    )
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
        QuickDocLocalization.previewOverride = "zh-Hans"
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

    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .container,
            rememberedPath: "/Volumes/Backup",
            frontWindow: .directory(home)
        ) == .usePath("/Volumes/Backup"),
        "外置卷快捷菜单应使用 Finder Sync 记下的挂载点"
    )
    expect(
        FinderMenuTargetPolicy.directoryForAction(
            origin: .container,
            rememberedPath: nil,
            frontWindow: .directory(home)
        ) == .cancel(.unresolved),
        "快捷菜单没有 Finder Sync 目标时不得退回主目录"
    )
    expect(
        FinderMenuTargetPolicy.menuBuildPlan(for: .container) == .rememberFinderSyncTarget,
        "外置卷快捷菜单仍不得在构建菜单时发送 AppleEvent"
    )

    let usb = ExternalVolumeAttributes(path: "/Volumes/Backup", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "USB")
    let diskImage = ExternalVolumeAttributes(path: "/Volumes/Installer", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "Disk Image")
    let network = ExternalVolumeAttributes(path: "/Volumes/Share", isLocal: false, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "SMB")
    let internalFabric = ExternalVolumeAttributes(path: "/Volumes/Recovery", isLocal: true, isInternal: true, isBrowsable: false, deviceInternal: true, deviceProtocol: "Apple Fabric")
    let simulator = ExternalVolumeAttributes(path: "/Library/Developer/CoreSimulator/Volumes/iOS", isLocal: true, isInternal: false, isBrowsable: false, deviceInternal: false, deviceProtocol: "Virtual Interface")
    let nested = ExternalVolumeAttributes(path: "/Volumes/Backup/Photos", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "USB")
    let thunderbolt = ExternalVolumeAttributes(path: "/Volumes/Archive", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "Thunderbolt")
    let root = ExternalVolumeAttributes(path: "/", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "USB")
    let volumesRoot = ExternalVolumeAttributes(path: "/Volumes", isLocal: true, isInternal: false, isBrowsable: true, deviceInternal: false, deviceProtocol: "USB")

    expect(FinderMenuTargetPolicy.externalVolumeContextMenuEnabled(sharedValue: nil) == false, "缺少设置时外置卷菜单必须关闭")
    expect(FinderMenuTargetPolicy.externalVolumeContextMenuEnabled(sharedValue: false) == false, "显式关闭必须保持关闭")
    expect(FinderMenuTargetPolicy.externalVolumeContextMenuEnabled(sharedValue: true), "显式开启才打开")
    expect(FinderMenuTargetPolicy.externalVolumeContextMenuEnabledKey == "externalVolumeContextMenuEnabled", "共享设置键必须稳定")

    let candidates = [usb, diskImage, network, internalFabric, simulator, nested, thunderbolt, root, volumesRoot, usb]
    expect(
        FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: false, volumes: candidates) == [home, "/Volumes"],
        "关闭时监视集合必须回到主目录和 /Volumes"
    )
    expect(
        FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: true, volumes: []) == [home, "/Volumes"],
        "开启但没有合格外置卷时不得扩大监视范围"
    )
    expect(
        FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: true, volumes: candidates) == [home, "/Volumes", "/Volumes/Archive", "/Volumes/Backup"],
        "开启时只加入合格外置卷挂载点，并去掉重复"
    )
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(diskImage), "磁盘映像不是外置硬盘")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(network), "网络卷不是外置硬盘")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(internalFabric), "内置 Apple Fabric 卷不能加入")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(simulator), "模拟器卷不能加入")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(nested), "不能监视挂载点下面的子目录")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(root), "不能把根目录当作外置卷")
    expect(!FinderMenuTargetPolicy.isSupportedExternalVolume(volumesRoot), "不能把 /Volumes 再扩大一次")

    let turnedOn = FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: true, volumes: [usb, thunderbolt])
    let unmounted = FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: true, volumes: [thunderbolt])
    let turnedOff = FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: false, volumes: [usb, thunderbolt])
    expect(turnedOn == [home, "/Volumes", "/Volumes/Archive", "/Volumes/Backup"], "重复计算开启集合应稳定")
    expect(unmounted == [home, "/Volumes", "/Volumes/Archive"], "卸载后应去掉对应挂载点")
    expect(turnedOff == [home, "/Volumes"], "再次关闭后不得留下外置卷")
    expect(turnedOn == FinderMenuTargetPolicy.monitoredDirectoryPaths(homePath: home, externalContextMenuEnabled: true, volumes: [thunderbolt, usb]), "开关反复打开不得产生重复项")

    let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("quickdoc-external-volume-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let temporaryPlist = temporaryDirectory.appendingPathComponent("settings.plist")
    if let legacyData = try? PropertyListSerialization.data(fromPropertyList: ["enabledFileTypes": ["txt"]], format: .xml, options: 0) {
        try? legacyData.write(to: temporaryPlist, options: .atomic)
        let legacy = (try? Data(contentsOf: temporaryPlist)).flatMap {
            try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? [String: Any]
        }
        expect(
            FinderMenuTargetPolicy.externalVolumeContextMenuEnabled(sharedValue: legacy?[FinderMenuTargetPolicy.externalVolumeContextMenuEnabledKey] as? Bool) == false,
            "旧版本设置文件缺少该键时必须关闭"
        )
    } else {
        expect(false, "无法写出隔离的旧设置文件")
    }
    try? FileManager.default.removeItem(at: temporaryDirectory)

    let simplifiedIdentifiers = [
        "zh-Hans", "zh-Hans-CN", "zh-Hans-SG", "zh-Hans-MY", "zh-Hans-HK", "zh-Hans-MO", "zh-Hans-TW", "zh_Hans_HK",
        "zh-CN", "zh-SG", "zh-MY"
    ]
    let traditionalIdentifiers = [
        "zh-Hant", "zh-Hant-TW", "zh-Hant-HK", "zh-Hant-MO", "zh-Hant-CN", "zh_Hant_HK",
        "zh-TW", "zh-HK", "zh-MO"
    ]
    for identifier in simplifiedIdentifiers {
        expect(QuickDocLocalization.code(matching: identifier) == "zh-Hans", "\(identifier) 应使用简体中文")
    }
    for identifier in traditionalIdentifiers {
        expect(QuickDocLocalization.code(matching: identifier) == "zh-Hant", "\(identifier) 应使用繁体中文")
    }
    expect(QuickDocLocalization.code(matching: "ja-JP") == "ja", "ja-JP 应使用日文")
    expect(QuickDocLocalization.code(matching: "en-GB") == "en", "en-GB 应使用英文")
    expect(QuickDocLocalization.code(matching: "fr-FR") == nil, "未支持的语言应留给英文 fallback")
    expect(
        QuickDocLocalization.code(matchingPreferred: ["zh-Hans-HK", "en-US", "zh-Hant-HK"]) == "zh-Hans",
        "简体排在繁体前面时应使用简体"
    )
    expect(
        QuickDocLocalization.code(matchingPreferred: ["zh-Hant-HK", "zh-Hans-HK"]) == "zh-Hant",
        "繁体排在简体前面时应使用繁体"
    )
    expect(
        QuickDocLocalization.code(matchingPreferred: ["zh-Hans-CN", "zh-Hant-TW"]) == "zh-Hans",
        "简体地区码排在前面时应使用简体"
    )
    expect(
        QuickDocLocalization.code(matchingPreferred: ["zh-Hant-TW", "zh-Hans-CN"]) == "zh-Hant",
        "繁体地区码排在前面时应使用繁体"
    )
    expect(
        QuickDocLocalization.code(matchingPreferred: ["fr-FR", "de-DE"]) == "en",
        "没有支持的语言时应回退英文"
    )
    expect(
        QuickDocLocalization.code(matchingPreferred: ["fr-FR", "zh-Hant-HK"]) == "zh-Hant",
        "应跳过未知语言并使用后面的繁体"
    )
    expect(QuickDocLocalization.code(matchingPreferred: []) == "en", "空语言列表应回退英文")
    expect(QuickDocLocalization.text("新建文件") == "新建文件", "预览锁定简体中文时菜单标题保持原文")
    QuickDocLocalization.previewOverride = "en"
    expect(QuickDocLocalization.text("新建文件") == "New File", "英文目录应翻译菜单标题")
    expect(!QuickDocLocalization.text("新建文件").contains("%"), "翻译结果不应留下占位符")
    QuickDocLocalization.previewOverride = "zh-Hans"
    runIsolatedLanguageChoiceTests()

    if !failures.isEmpty {
        fputs("\(failures.count) failed\n", stderr)
        exit(1)
    }
    print("PASS \(checks) finder menu target policy checks")
    }
}
