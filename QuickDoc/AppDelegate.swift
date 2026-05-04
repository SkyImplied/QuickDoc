import Cocoa
import Carbon
import FinderSync
import os
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "com.skyimplied.QuickDoc", category: "AppDelegate")
    private let settingsModel = QuickDocSettingsModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private static let terminalPathQueryKey = "path"
    private var initialWindowWorkItem: DispatchWorkItem?
    private var shouldSuppressInitialWindow = false

    override init() {
        super.init()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsModel.onDisplayModeDidChange = { [weak self] mode in
            self?.applyDisplayMode(mode)
        }
        applyDisplayMode(settingsModel.displayMode)
        scheduleInitialWindowPresentation()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handleIncomingURL(_:))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func showMainWindow() {
        cancelInitialWindowPresentation()
        shouldSuppressInitialWindow = false

        if window == nil {
            window = makeMainWindow()
        }

        applyDisplayMode(settingsModel.displayMode)

        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeMainWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickDoc"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 1120, height: 700)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.contentView = NSHostingView(rootView: QuickDocSettingsView(model: settingsModel))
        return window
    }

    private func applyDisplayMode(_ mode: QuickDocDisplayMode) {
        updateStatusItemVisibility(for: mode)

        let targetPolicy = mode.activationPolicy
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
        }
    }

    private func updateStatusItemVisibility(for mode: QuickDocDisplayMode) {
        if mode.showsStatusItem {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                configureStatusItem(item)
                statusItem = item
            } else {
                refreshStatusItemAppearance()
            }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func configureStatusItem(_ item: NSStatusItem) {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "QuickDoc 正在运行"
        refreshStatusItemAppearance()
    }

    private func refreshStatusItemAppearance() {
        guard let button = statusItem?.button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = statusBarImage()
    }

    private func statusBarImage() -> NSImage? {
        guard let baseImage = NSApp.applicationIconImage else { return nil }
        let image = (baseImage.copy() as? NSImage) ?? baseImage
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private func presentStatusMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let openSettingsItem = NSMenuItem(title: "打开设置", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: "")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)
        menu.addItem(.separator())

        let displayModeItem = NSMenuItem(title: "显示方式", action: nil, keyEquivalent: "")
        let displayModeMenu = NSMenu()
        for mode in QuickDocDisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectDisplayModeFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settingsModel.displayMode == mode ? .on : .off
            displayModeMenu.addItem(item)
        }
        displayModeItem.submenu = displayModeMenu
        menu.addItem(displayModeItem)

        let launchAtLoginItem = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = settingsModel.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let finderItem = NSMenuItem(title: "重启访达", action: #selector(restartFinderFromMenu(_:)), keyEquivalent: "")
        finderItem.target = self
        menu.addItem(finderItem)

        let extensionItem = NSMenuItem(title: "打开扩展设置", action: #selector(openExtensionSettingsFromMenu(_:)), keyEquivalent: "")
        extensionItem.target = self
        menu.addItem(extensionItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 QuickDoc", action: #selector(quitApplication(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func handleStatusItemClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            presentStatusMenu()
        } else {
            showMainWindow()
        }
    }

    @objc
    private func openSettingsFromMenu(_ sender: Any?) {
        showMainWindow()
    }

    @objc
    private func selectDisplayModeFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = QuickDocDisplayMode(rawValue: rawValue) else {
            return
        }

        settingsModel.requestDisplayModeChange(mode)
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: Any?) {
        settingsModel.launchAtLogin.toggle()
    }

    @objc
    private func restartFinderFromMenu(_ sender: Any?) {
        settingsModel.restartFinder()
    }

    @objc
    private func openExtensionSettingsFromMenu(_ sender: Any?) {
        settingsModel.openExtensionSettings()
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func handleIncomingURL(_ url: URL) {
        shouldSuppressInitialWindow = true
        cancelInitialWindowPresentation()

        guard url.scheme == "quickdoc",
              url.host == "open-terminal",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedPath = components.queryItems?.first(where: { $0.name == Self.terminalPathQueryKey })?.value,
              let path = encodedPath.removingPercentEncoding else {
            logger.error("Ignored unsupported URL: \(url.absoluteString, privacy: .public)")
            return
        }

        logger.info("Received terminal open request for \(path, privacy: .public)")
        openTerminal(atPath: path)
    }

    private func openTerminal(atPath path: String) {
        let directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            logger.error("Terminal open path does not exist: \(path, privacy: .public)")
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        if runTerminalAppleScript(for: directoryURL.path) {
            return
        }

        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true

        NSWorkspace.shared.open([directoryURL], withApplicationAt: terminalURL, configuration: configuration) { runningApplication, error in
            if error != nil {
                self.logger.error("Fallback Terminal open failed for \(directoryURL.path, privacy: .public)")
                return
            }

            runningApplication?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    @objc
    private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            logger.error("Received malformed Apple Event URL")
            return
        }

        handleIncomingURL(url)
    }

    private func runTerminalAppleScript(for path: String) -> Bool {
        let escapedPath = appleScriptEscapedString(path)
        let source = """
        set targetPath to "\(escapedPath)"
        tell application "Terminal"
            do script ("cd " & quoted form of targetPath)
            activate
        end tell
        """

        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)

        if let error {
            logger.error("AppleScript terminal open failed: \(String(describing: error), privacy: .public)")
            return false
        }

        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal")
            .first?
            .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        logger.info("Opened Terminal via AppleScript for \(path, privacy: .public)")
        return true
    }

    private func appleScriptEscapedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func scheduleInitialWindowPresentation() {
        cancelInitialWindowPresentation()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.shouldSuppressInitialWindow else { return }
            self.showMainWindow()
        }
        initialWindowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func cancelInitialWindowPresentation() {
        initialWindowWorkItem?.cancel()
        initialWindowWorkItem = nil
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case permissions
    case fileTypes
    case finder
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用"
        case .permissions: return "权限与扩展"
        case .fileTypes: return "新建文件类型"
        case .finder: return "访达操作"
        case .about: return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .permissions: return "checkmark.shield"
        case .fileTypes: return "doc.text"
        case .finder: return "folder"
        case .about: return "info.circle"
        }
    }
}

private enum QuickDocDisplayMode: String, CaseIterable, Identifiable {
    case menuBarOnly
    case hiddenBoth
    case dockOnly
    case menuBarAndDock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBarOnly:
            return "仅在菜单栏显示"
        case .hiddenBoth:
            return "隐藏菜单栏和 Dock"
        case .dockOnly:
            return "仅在 Dock 栏显示"
        case .menuBarAndDock:
            return "菜单栏和 Dock 同时显示"
        }
    }

    var subtitle: String {
        switch self {
        case .menuBarOnly:
            return "默认推荐，常驻状态栏，点击图标可快速打开设置。"
        case .hiddenBoth:
            return "后台静默运行，不显示菜单栏与 Dock，可通过再次启动应用重新打开。"
        case .dockOnly:
            return "保留当前传统窗口应用行为，仅通过 Dock 使用。"
        case .menuBarAndDock:
            return "同时保留菜单栏入口与 Dock 图标，适合双入口习惯。"
        }
    }

    var activationPolicy: NSApplication.ActivationPolicy {
        switch self {
        case .menuBarOnly, .hiddenBoth:
            return .accessory
        case .dockOnly, .menuBarAndDock:
            return .regular
        }
    }

    var showsStatusItem: Bool {
        switch self {
        case .menuBarOnly, .menuBarAndDock:
            return true
        case .hiddenBoth, .dockOnly:
            return false
        }
    }
}

private struct FileType: Identifiable, Hashable {
    let id: String
    let title: String
    let menuTitle: String
    let pathExtension: String?
    let enabledByDefault: Bool
}

private struct MenuPreviewItem: Identifiable, Hashable {
    let id: String
    let title: String
}

private enum QuickDocIcon {
    private static let builtInIconResourceNames: [String: String] = [
        "txt": "txt",
        "md": "md",
        "docx": "word_icon",
        "xlsx": "excel",
        "csv": "CSV",
        "pptx": "PPT",
        "json": "json",
        "blank": "空白",
        "py": "python",
        "html": "html",
        "sh": "shell",
        "rtf": "rtf"
    ]

    @MainActor
    static func icon(for id: String, size: NSSize) -> NSImage? {
        guard let resourceName = builtInIconResourceNames[id],
              let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = size
        image.isTemplate = false
        return image
    }
}

private let quickDocFileTypes: [FileType] = [
    FileType(id: "txt", title: "TXT", menuTitle: "新建 TXT 文件", pathExtension: "txt", enabledByDefault: true),
    FileType(id: "md", title: "Markdown (.md)", menuTitle: "新建 Markdown 文件", pathExtension: "md", enabledByDefault: true),
    FileType(id: "docx", title: "Word (.docx)", menuTitle: "新建 Word 文档", pathExtension: "docx", enabledByDefault: true),
    FileType(id: "xlsx", title: "Excel (.xlsx)", menuTitle: "新建 Excel 表格", pathExtension: "xlsx", enabledByDefault: true),
    FileType(id: "csv", title: "CSV", menuTitle: "新建 CSV 表格", pathExtension: "csv", enabledByDefault: true),
    FileType(id: "pptx", title: "PowerPoint (.pptx)", menuTitle: "新建 PowerPoint 演示文稿", pathExtension: "pptx", enabledByDefault: true),
    FileType(id: "json", title: "JSON", menuTitle: "新建 JSON 文件", pathExtension: "json", enabledByDefault: true),
    FileType(id: "blank", title: "空白文件", menuTitle: "新建空白文件", pathExtension: nil, enabledByDefault: true),
    FileType(id: "py", title: "Python (.py)", menuTitle: "新建 Python 文件", pathExtension: "py", enabledByDefault: false),
    FileType(id: "html", title: "HTML", menuTitle: "新建 HTML 文件", pathExtension: "html", enabledByDefault: false),
    FileType(id: "sh", title: "Shell (.sh)", menuTitle: "新建 Shell 文件", pathExtension: "sh", enabledByDefault: false),
    FileType(id: "rtf", title: "Rich Text (.rtf)", menuTitle: "新建 RTF 文件", pathExtension: "rtf", enabledByDefault: false)
]

private struct QuickDocSettingsView: View {
    @ObservedObject private var model: QuickDocSettingsModel
    @State private var selection: SettingsPage? = .general
    private let sidebarWidth: CGFloat = 282
    private let detailMinWidth: CGFloat = 760

    init(model: QuickDocSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)
                    .fixedSize(horizontal: true, vertical: false)
                Divider()
                ScrollView {
                    selectedPage
                        .padding(.horizontal, 36)
                        .padding(.vertical, 30)
                        .frame(maxWidth: 1020, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .scrollContentBackground(.hidden)
                .background(GlassBackground())
            }

            Color.clear
                .frame(height: 58)
                .contentShape(Rectangle())
                .ifAvailableWindowDragGesture()
        }
        .frame(minWidth: sidebarWidth + detailMinWidth + 1, minHeight: 700)
        .environmentObject(model)
    }

    private var sidebar: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 74, height: 74)
                        .shadow(radius: 8, y: 4)

                    Text("QuickDoc")
                        .font(.title2.weight(.bold))

                    Text("版本 \(model.appVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 12)

                List(SettingsPage.allCases, selection: $selection) { page in
                    Label(page.title, systemImage: page.systemImage)
                        .font(.body.weight(.medium))
                        .tag(page)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsPage()
        case .permissions:
            PermissionsPage()
        case .fileTypes:
            FileTypesPage()
        case .finder:
            FinderActionsPage()
        case .about:
            AboutPage()
        }
    }
}

private struct GeneralSettingsPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "通用设置", subtitle: "管理 QuickDoc 的启动行为与基础偏好。")

            GlassSection {
                Toggle("开机自启动", isOn: $model.launchAtLogin)
                Text("登录 macOS 时自动启动 QuickDoc。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            DisplayModeSettingsCard()
            QuickAccessSettingsCard()
            LanguageSettingsCard()
        }
    }
}

private struct DisplayModeSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("显示方式")
                        .font(.headline)
                    Text("控制 QuickDoc 在菜单栏与 Dock 中的显示方式，默认推荐常驻菜单栏。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(QuickDocDisplayMode.allCases) { mode in
                        Button {
                            model.requestDisplayModeChange(mode)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: model.displayMode == mode ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(model.displayMode == mode ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mode.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(mode.subtitle)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(model.displayMode == mode ? Color.accentColor.opacity(0.10) : Color.clear)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(model.displayMode == mode ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct PermissionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "权限与扩展", subtitle: "确认 Finder Sync 扩展已在系统设置中启用。")
            PermissionStatusCard()
        }
    }
}

private struct FileTypesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "新建文件类型", subtitle: "选择要出现在 Finder 右键菜单里的文件类型，并添加自定义后缀。")
            FileTypesCard()
            MenuPreviewCard()
        }
    }
}

private struct FinderActionsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "访达操作", subtitle: "当右键菜单未刷新时，重启 Finder 可强制重新载入扩展。")
            FinderRestartCard()
        }
    }
}

private struct AboutPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "关于", subtitle: "QuickDoc 让 Finder 右键新建文件更快、更顺手。")

            GlassSection {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("QuickDoc")
                            .font(.title2.weight(.bold))
                        Text("版本 v\(model.appVersion)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("为 Finder 右键菜单提供一键新建常用文件的效率工具。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 220), spacing: 14),
                GridItem(.flexible(minimum: 220), spacing: 14)
            ], alignment: .leading, spacing: 14) {
                AboutFeatureCard(
                    systemImage: "doc.badge.plus",
                    title: "常用文件一键新建",
                    subtitle: "支持 TXT、Markdown、Word、Excel、PPT、JSON 等常见文件类型。"
                )
                AboutFeatureCard(
                    systemImage: "slider.horizontal.3",
                    title: "自定义后缀",
                    subtitle: "按需添加常用扩展名，让右键菜单更贴合你的工作流。"
                )
                AboutFeatureCard(
                    systemImage: "folder.badge.gearshape",
                    title: "访达右键集成",
                    subtitle: "直接从 Finder 菜单创建文件，不必切换应用。"
                )
                AboutFeatureCard(
                    systemImage: "checkmark.shield",
                    title: "权限与扩展管理",
                    subtitle: "在应用内查看扩展状态，并快速跳转系统设置。"
                )
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 10) {
                    Label("声明", systemImage: "info.circle")
                        .font(.headline)
                    Text("本软件为免费开源项目，仅供交流学习与个人使用。请遵守相关法律法规与开源协议，勿用于任何商业或非法用途。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GlassSection {
                VStack(alignment: .leading, spacing: 12) {
                    Label("联系与主页", systemImage: "link")
                        .font(.headline)

                    ContactRow(title: "Bilibili", value: "默示天空")
                    ContactRow(title: "GitHub", value: "SkyImplied")
                    ContactRow(title: "邮箱", value: "skyimplied@163.com")
                }
            }
        }
    }
}

private struct AboutFeatureCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ContactRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.callout)
        }
    }
}

private struct LanguageOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

private let quickDocLanguageOptions: [LanguageOption] = [
    LanguageOption(id: "zh-Hans", title: "简体中文", subtitle: "适合中国大陆用户"),
    LanguageOption(id: "en", title: "English", subtitle: "International"),
    LanguageOption(id: "ja", title: "日本语", subtitle: "Japanese"),
    LanguageOption(id: "ko", title: "한국어", subtitle: "Korean"),
    LanguageOption(id: "fr", title: "Français", subtitle: "French"),
    LanguageOption(id: "de", title: "Deutsch", subtitle: "German")
]

private struct LanguageSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isPresentingLanguageSheet = false

    var body: some View {
        GlassSection {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("软件语言")
                        .font(.headline)
                    Text("点击后再选择语言，v1.1 暂不支持实际切换。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("语言设置") {
                    isPresentingLanguageSheet = true
                }
                .glassButtonStyle()
            }
        }
        .sheet(isPresented: $isPresentingLanguageSheet) {
            LanguageSelectionSheet()
                .environmentObject(model)
        }
    }
}

private struct QuickAccessSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "command")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("终端直达与路径复制")
                            .font(.headline)
                        Text("开启后会在 Finder 右键一级菜单显示“在终端中打开”和“复制当前路径”。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("启用终端直达", isOn: $model.terminalDirectEnabled)
                Toggle("启用路径复制", isOn: $model.pathCopyEnabled)

                Text("开启后可直接在右键菜单里打开终端或复制当前文件夹路径。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LanguageSelectionSheet: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(minimum: 180), spacing: 12),
        GridItem(.flexible(minimum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("选择软件语言")
                    .font(.title3.weight(.bold))
                Text("以下语言将在未来版本逐步支持，当前仅展示选择入口。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(quickDocLanguageOptions) { option in
                    Button {
                        model.showLanguageComingSoon(languageName: option.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .glassButtonStyle()
            }
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 320)
    }
}

private struct PermissionStatusCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        let status = model.extensionStatus

        GlassSection {
            HStack(alignment: .center, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("系统扩展权限")
                            .font(.headline)
                        Text(status.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.shield")
                }

                Spacer()

                Text(status.badgeTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(status.backgroundTint, in: Capsule())

                Button("打开系统设置") {
                    model.openExtensionSettings()
                }
                .glassButtonStyle()
            }
        }
    }
}

private struct FinderRestartCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            HStack(spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("重启访达")
                            .font(.headline)
                        Text("当右键菜单未更新时，可重启 Finder 使扩展生效")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "folder.badge.gearshape")
                }

                Spacer()

                Button("立即重启 Finder") {
                    model.restartFinder()
                }
                .disabled(model.isRestartingFinder)
                .glassButtonStyle(prominent: true)
            }
        }
    }
}

private struct FileTypesCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var customExtension = ""

    private let columns = [
        GridItem(.flexible(minimum: 150), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(quickDocFileTypes) { type in
                        Toggle(type.title, isOn: Binding(
                            get: { model.enabledFileTypes.contains(type.id) },
                            set: { model.setFileType(type.id, enabled: $0) }
                        ))
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Text("自定义后缀")
                        .font(.callout.weight(.medium))
                    TextField("输入扩展名，例如 .yaml", text: $customExtension)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addCustomExtension)
                    Button("添加") {
                        addCustomExtension()
                    }
                    .glassButtonStyle()
                }

                if !model.customExtensions.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(model.customExtensions, id: \.self) { fileExtension in
                            HStack(spacing: 8) {
                                Text(".\(fileExtension)")
                                    .font(.callout.weight(.medium))
                                Button {
                                    model.removeCustomExtension(fileExtension)
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                        }
                    }
                }

                Text("勾选后将显示在 Finder 右键新建菜单中")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addCustomExtension() {
        guard model.addCustomExtension(customExtension) else { return }
        customExtension = ""
    }
}

private struct MenuPreviewCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @State private var isEditingOrder = false
    @State private var editingSelectionOrder: [String] = []
    @State private var baselineVisibleOrder: [String] = []

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("访达右键菜单预览")
                            .font(.headline)
                        Text("这里会模拟 Finder 里“新建文件”的展示顺序，编辑后右键菜单也会同步更新。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(isEditingOrder ? "完成排序" : "编辑排序") {
                        toggleEditingOrder()
                    }
                    .glassButtonStyle()
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 14) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 74, height: 74)
                                .overlay {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("右键菜单样式")
                                    .font(.title3.weight(.semibold))
                                Text("当前已启用 \(model.menuPreviewItems.count) 项")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            PreviewTipRow(
                                systemImage: isEditingOrder ? "checklist.checked" : "hand.tap",
                                text: helperText
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(width: 320, alignment: .leading)

                    menuPreviewPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var helperText: String {
        if isEditingOrder {
            return "请按目标顺序依次点击左侧圆圈。第一次点击排第 1，第二次点击排第 2；再次点击已选项可取消。"
        }

        return "点击“编辑排序”后，可通过左侧圆圈按顺序设置菜单位置，排序后 Finder 右键菜单会同步更新。"
    }

    private var menuPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundStyle(.secondary)
                Text("Finder > 新建文件")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                if model.menuPreviewItems.isEmpty {
                    PreviewMenuRow(
                        item: MenuPreviewItem(id: "empty", title: "暂无启用的新建类型"),
                        isEditing: false,
                        selectionRank: nil,
                        showsChevron: false,
                        onSelect: nil
                    )
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                } else {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.menuPreviewItems) { item in
                            PreviewMenuRow(
                                item: item,
                                isEditing: isEditingOrder,
                                selectionRank: selectionRank(for: item.id),
                                showsChevron: !isEditingOrder,
                                onSelect: isEditingOrder ? {
                                    toggleSelection(for: item.id)
                                } : nil
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(minHeight: 290)
            .animation(.snappy(duration: 0.22), value: model.menuPreviewItems.map(\.id))
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private func toggleEditingOrder() {
        if isEditingOrder {
            isEditingOrder = false
            editingSelectionOrder = []
            baselineVisibleOrder = []
            return
        }

        baselineVisibleOrder = model.menuPreviewItems.map(\.id)
        editingSelectionOrder = []
        isEditingOrder = true
    }

    private func toggleSelection(for itemID: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if let index = editingSelectionOrder.firstIndex(of: itemID) {
                editingSelectionOrder.remove(at: index)
            } else {
                editingSelectionOrder.append(itemID)
            }

            model.applyPreviewSelectionOrder(editingSelectionOrder, baseVisibleOrder: baselineVisibleOrder)
        }
    }

    private func selectionRank(for itemID: String) -> Int? {
        guard let index = editingSelectionOrder.firstIndex(of: itemID) else { return nil }
        return index + 1
    }
}

private struct PreviewMenuRow: View {
    let item: MenuPreviewItem
    let isEditing: Bool
    let selectionRank: Int?
    let showsChevron: Bool
    let onSelect: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                selectionBadge
            }
            previewIcon
                .frame(width: 18, height: 18)
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
        .padding(.horizontal, 14)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing else { return }
            onSelect?()
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        Button {
            onSelect?()
        } label: {
            ZStack {
                Circle()
                    .stroke(selectionRank == nil ? Color.secondary.opacity(0.45) : Color.accentColor, lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(selectionRank == nil ? Color.clear : Color.accentColor.opacity(0.14))
                    )
                    .frame(width: 24, height: 24)

                if let selectionRank {
                    Text("\(selectionRank)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var previewIcon: some View {
        if let image = QuickDocIcon.icon(for: item.id, size: NSSize(width: 18, height: 18)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isEditing, selectionRank != nil {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        } else {
            Color.clear
        }
    }
}

private struct PreviewTipRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 18)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.weight(.bold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GlassSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard()
    }
}

private struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.blue.opacity(0.07),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

@MainActor
private final class QuickDocSettingsModel: ObservableObject {
    struct AlertContent {
        let title: String
        let message: String
        let style: NSAlert.Style
    }

    struct ExtensionStatus {
        let isConfirmed: Bool

        var badgeTitle: String {
            isConfirmed ? "已确认" : "需确认"
        }

        var description: String {
            if isConfirmed {
                return "QuickDoc Finder Sync 扩展已启用，可以正常显示在 Finder 右键菜单中。"
            }

            return "请在 系统设置 > 隐私与安全性 > 登录项与扩展 中启用 QuickDoc 扩展"
        }

        var tint: Color {
            isConfirmed ? .green : .red
        }

        var backgroundTint: Color {
            tint.opacity(0.12)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

    @Published private(set) var displayMode: QuickDocDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: Self.displayModeKey)
            onDisplayModeDidChange?(displayMode)
        }
    }

    @Published private(set) var extensionStatus = ExtensionStatus(isConfirmed: false)
    @Published private(set) var isRestartingFinder = false

    @Published var enabledFileTypes: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledFileTypes), forKey: Self.enabledFileTypesKey)
            writeSharedSettings()
        }
    }

    @Published var customExtensions: [String] {
        didSet {
            UserDefaults.standard.set(customExtensions, forKey: Self.customExtensionsKey)
            reconcileMenuOrder()
            writeSharedSettings()
        }
    }

    @Published var terminalDirectEnabled: Bool {
        didSet {
            UserDefaults.standard.set(terminalDirectEnabled, forKey: Self.terminalDirectEnabledKey)
            writeSharedSettings()
        }
    }

    @Published var pathCopyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(pathCopyEnabled, forKey: Self.pathCopyEnabledKey)
            writeSharedSettings()
        }
    }

    @Published private var menuOrder: [String] {
        didSet {
            UserDefaults.standard.set(menuOrder, forKey: Self.menuOrderKey)
            writeSharedSettings()
        }
    }

    let appVersion: String
    var onDisplayModeDidChange: ((QuickDocDisplayMode) -> Void)?
    private var notificationObservers: [NSObjectProtocol] = []
    private static let displayModeKey = "displayMode"
    private static let terminalDirectEnabledKey = "terminalDirectEnabled"
    private static let pathCopyEnabledKey = "pathCopyEnabled"
    private static let enabledFileTypesKey = "enabledFileTypes"
    private static let customExtensionsKey = "customExtensions"
    private static let menuOrderKey = "menuOrder"

    init() {
        let defaultTypes = quickDocFileTypes.filter(\.enabledByDefault).map(\.id)
        UserDefaults.standard.register(defaults: [
            Self.displayModeKey: QuickDocDisplayMode.menuBarOnly.rawValue,
            Self.terminalDirectEnabledKey: true,
            Self.pathCopyEnabledKey: true,
            Self.enabledFileTypesKey: defaultTypes,
            Self.customExtensionsKey: [],
            Self.menuOrderKey: Self.defaultMenuOrder
        ])
        let sharedSettings = Self.readSharedSettings()

        launchAtLogin = SMAppService.mainApp.status == .enabled
        displayMode = QuickDocDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: Self.displayModeKey) ?? QuickDocDisplayMode.menuBarOnly.rawValue
        ) ?? .menuBarOnly
        terminalDirectEnabled = sharedSettings.terminalDirectEnabled ?? UserDefaults.standard.object(forKey: Self.terminalDirectEnabledKey) as? Bool ?? true
        pathCopyEnabled = sharedSettings.pathCopyEnabled ?? UserDefaults.standard.object(forKey: Self.pathCopyEnabledKey) as? Bool ?? true
        let storedCustomExtensions = sharedSettings.customExtensions ?? UserDefaults.standard.stringArray(forKey: Self.customExtensionsKey) ?? []
        enabledFileTypes = Set(sharedSettings.enabledFileTypes ?? UserDefaults.standard.stringArray(forKey: Self.enabledFileTypesKey) ?? defaultTypes)
        customExtensions = storedCustomExtensions
        menuOrder = Self.normalizedMenuOrder(sharedSettings.menuOrder ?? UserDefaults.standard.stringArray(forKey: Self.menuOrderKey) ?? Self.defaultMenuOrder, customExtensions: storedCustomExtensions)
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        reconcileMenuOrder()
        writeSharedSettings()
        refreshExtensionStatus()
        observeAppActivation()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var menuPreviewItems: [MenuPreviewItem] {
        menuOrder.compactMap { id in
            guard enabledFileTypes.contains(id) || id.hasPrefix(Self.customMenuIDPrefix) else {
                return nil
            }
            return menuItem(for: id)
        }
    }

    func setFileType(_ id: String, enabled: Bool) {
        if enabled {
            enabledFileTypes.insert(id)
        } else {
            enabledFileTypes.remove(id)
        }
        reconcileMenuOrder()
    }

    func addCustomExtension(_ value: String) -> Bool {
        let normalized = normalizeExtension(value)
        guard !normalized.isEmpty else {
            showAlert(title: "无法添加后缀", message: "请输入文件后缀，例如 yaml 或 .log。")
            return false
        }

        guard quickDocFileTypes.allSatisfy({ $0.pathExtension != normalized }) else {
            showAlert(title: "后缀已存在", message: ".\(normalized) 已在内置文件类型中。")
            return false
        }

        guard !customExtensions.contains(normalized) else {
            showAlert(title: "后缀已存在", message: ".\(normalized) 已经添加。")
            return false
        }

        customExtensions.append(normalized)
        return true
    }

    func removeCustomExtension(_ value: String) {
        customExtensions.removeAll { $0 == value }
    }

    func applyPreviewSelectionOrder(_ prioritizedIDs: [String], baseVisibleOrder: [String]) {
        let currentlyVisibleIDs = Set(menuPreviewItems.map(\.id))
        let normalizedPriorities = prioritizedIDs.filter { currentlyVisibleIDs.contains($0) }
        let remainingVisibleIDs = baseVisibleOrder.filter {
            currentlyVisibleIDs.contains($0) && !normalizedPriorities.contains($0)
        }
        let visibleOrder = normalizedPriorities + remainingVisibleIDs
        let visibleIDSet = Set(visibleOrder)
        let hiddenOrderedIDs = menuOrder.filter { !visibleIDSet.contains($0) }
        menuOrder = Self.normalizedMenuOrder(visibleOrder + hiddenOrderedIDs, customExtensions: customExtensions)
    }

    func openExtensionSettings() {
        refreshExtensionStatus()

        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshExtensionStatus() {
        extensionStatus = ExtensionStatus(isConfirmed: FIFinderSyncController.isExtensionEnabled)
    }

    func requestDisplayModeChange(_ newMode: QuickDocDisplayMode) {
        guard newMode != displayMode else { return }

        if newMode == .hiddenBoth {
            let alert = NSAlert()
            alert.messageText = "确认隐藏菜单栏与 Dock"
            alert.informativeText = "切换后 QuickDoc 将不在菜单栏和 Dock 中显示，只会在后台运行。你仍可通过再次启动应用重新打开设置界面。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续切换")
            alert.addButton(withTitle: "取消")

            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        displayMode = newMode
    }

    func restartFinder() {
        guard !isRestartingFinder else { return }
        isRestartingFinder = true

        Task {
            let alert = await restartFinderWorkflow()
            isRestartingFinder = false
            showAlert(alert)
        }
    }

    func showLanguageComingSoon(languageName: String) {
        showAlert(
            title: "功能等待未来更新",
            message: "\(languageName) 语言支持正在规划中，v1.1 暂未开放，敬请期待后续版本更新。"
        )
    }

    func showFeatureComingSoon(featureName: String) {
        showAlert(
            title: "功能等待未来更新",
            message: "\(featureName) 功能正在规划中，v1.1 暂未开放，敬请期待后续版本更新。"
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            showAlert(title: "开机自启动设置失败", message: error.localizedDescription)
        }
    }

    private func observeAppActivation() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshExtensionStatus()
            }
        }

        notificationObservers.append(observer)
    }

    private func restartFinderWorkflow() async -> AlertContent {
        let finderBundleIdentifier = "com.apple.finder"
        let wasRunningBeforeRestart = isApplicationRunning(bundleIdentifier: finderBundleIdentifier)

        let terminateResult = await runProcess(
            executablePath: "/usr/bin/killall",
            arguments: ["Finder"]
        )

        guard terminateResult.exitCode == 0 else {
            return AlertContent(
                title: "重启 Finder 失败",
                message: terminateResult.errorDescription ?? "Finder 进程结束命令返回了退出码 \(terminateResult.exitCode)。",
                style: .warning
            )
        }

        if wasRunningBeforeRestart {
            try? await Task.sleep(for: .milliseconds(250))
        }

        let relaunchSucceeded = await waitForFinderToLaunch(bundleIdentifier: finderBundleIdentifier)
        guard relaunchSucceeded else {
            return AlertContent(
                title: "重启 Finder 失败",
                message: "Finder 已退出，但未能自动重新启动，请手动打开访达后重试。",
                style: .warning
            )
        }

        return AlertContent(
            title: "重启 Finder 成功",
            message: "访达已经重新启动，扩展刷新应已生效。",
            style: .informational
        )
    }

    private func waitForFinderToLaunch(bundleIdentifier: String) async -> Bool {
        for _ in 0..<40 {
            let isRunning = isApplicationRunning(bundleIdentifier: bundleIdentifier)
            if isRunning {
                return true
            }

            try? await Task.sleep(for: .milliseconds(100))
        }

        return false
    }

    private func isApplicationRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    private func runProcess(executablePath: String, arguments: [String]) async -> ProcessResult {
        return await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.terminationHandler = { process in
                let output = readPipe(outputPipe)
                let error = readPipe(errorPipe)
                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    output: output,
                    error: error
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: ProcessResult(
                    exitCode: -1,
                    output: "",
                    error: error.localizedDescription
                ))
            }
        }
    }

    private func normalizeExtension(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasPrefix(".") {
            normalized.removeFirst()
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-+")
        normalized = String(normalized.unicodeScalars.filter { allowed.contains($0) })
        return String(normalized.prefix(24))
    }

    private func writeSharedSettings() {
        let payload: [String: Any] = [
            Self.enabledFileTypesKey: Array(enabledFileTypes),
            Self.customExtensionsKey: customExtensions,
            Self.menuOrderKey: menuOrder,
            Self.terminalDirectEnabledKey: terminalDirectEnabled,
            Self.pathCopyEnabledKey: pathCopyEnabled
        ]

        do {
            let directory = Self.sharedSettingsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
            try data.write(to: Self.sharedSettingsURL, options: .atomic)
        } catch {
            NSLog("QuickDoc shared settings write failed: \(error.localizedDescription)")
        }
    }

    private static func readSharedSettings() -> (enabledFileTypes: [String]?, customExtensions: [String]?, menuOrder: [String]?, terminalDirectEnabled: Bool?, pathCopyEnabled: Bool?) {
        guard let data = try? Data(contentsOf: sharedSettingsURL),
              let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (nil, nil, nil, nil, nil)
        }

        return (
            payload[enabledFileTypesKey] as? [String],
            payload[customExtensionsKey] as? [String],
            payload[menuOrderKey] as? [String],
            payload[terminalDirectEnabledKey] as? Bool,
            payload[pathCopyEnabledKey] as? Bool
        )
    }

    private static var sharedSettingsURL: URL {
        URL(fileURLWithPath: "/Users/\(NSUserName())")
            .appendingPathComponent("Library/Application Support/QuickDoc/settings.plist")
    }

    private static let customMenuIDPrefix = "custom."

    private static var defaultMenuOrder: [String] {
        quickDocFileTypes.map(\.id)
    }

    private static func customMenuID(for fileExtension: String) -> String {
        "\(customMenuIDPrefix)\(fileExtension)"
    }

    private static func normalizedMenuOrder(_ order: [String], customExtensions: [String]) -> [String] {
        let allIDs = defaultMenuOrder + customExtensions.map(customMenuID(for:))
        var seen: Set<String> = []
        var normalized: [String] = []

        for id in order where allIDs.contains(id) && !seen.contains(id) {
            normalized.append(id)
            seen.insert(id)
        }

        for id in allIDs where !seen.contains(id) {
            normalized.append(id)
        }

        return normalized
    }

    private func reconcileMenuOrder() {
        let normalized = Self.normalizedMenuOrder(menuOrder, customExtensions: customExtensions)
        if normalized != menuOrder {
            menuOrder = normalized
        }
    }

    private func menuItem(for id: String) -> MenuPreviewItem? {
        if let builtIn = quickDocFileTypes.first(where: { $0.id == id }) {
            return MenuPreviewItem(id: id, title: builtIn.menuTitle)
        }

        guard id.hasPrefix(Self.customMenuIDPrefix) else { return nil }
        let fileExtension = String(id.dropFirst(Self.customMenuIDPrefix.count))
        guard customExtensions.contains(fileExtension) else { return nil }
        return MenuPreviewItem(id: id, title: "新建 \(fileExtension.uppercased()) 文件")
    }

    private func showAlert(_ content: AlertContent) {
        let alert = NSAlert()
        alert.messageText = content.title
        alert.informativeText = content.message
        alert.alertStyle = content.style
        alert.runModal()
    }

    private func showAlert(title: String, message: String) {
        showAlert(AlertContent(title: title, message: message, style: .informational))
    }
}

private struct ProcessResult {
    let exitCode: Int32
    let output: String
    let error: String

    var errorDescription: String? {
        if !error.isEmpty {
            return error
        }

        if !output.isEmpty {
            return output
        }

        return nil
    }
}

private func readPipe(_ pipe: Pipe) -> String {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

private extension View {
    @ViewBuilder
    func liquidGlassCard() -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func ifAvailableWindowDragGesture() -> some View {
        if #available(macOS 15.0, *) {
            self
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        } else {
            self
        }
    }
}
