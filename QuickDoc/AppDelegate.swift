import Cocoa
import Carbon
import FinderSync
import os
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class PersistentMenuToggleView: NSView {
    private let button: NSButton
    private let onToggle: (Bool) -> Void

    init(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        self.onToggle = onToggle
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 24))

        button.frame = bounds.insetBy(dx: 8, dy: 0)
        button.autoresizingMask = [.width, .height]
        button.font = NSFont.menuFont(ofSize: 0)
        button.state = isOn ? .on : .off
        button.target = self
        button.action = #selector(handleToggle(_:))
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func handleToggle(_ sender: NSButton) {
        onToggle(sender.state == .on)
    }
}
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "com.skyimplied.QuickDoc", category: "AppDelegate")
    private let settingsModel = QuickDocSettingsModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private static let terminalPathQueryKey = "path"
    private static let loginLaunchHost = "launch-at-login"
    private static let permanentDeleteHost = "permanent-delete"
    private static let permanentDeleteRequestQueryKey = "request"
    private static let suppressInitialWindowEnvironmentKey = "QUICKDOC_SUPPRESS_INITIAL_WINDOW"
    private var initialWindowWorkItem: DispatchWorkItem?
    private var shouldSuppressInitialWindow = ProcessInfo.processInfo.environment[suppressInitialWindowEnvironmentKey] == "1"
    private var isHandlingPermanentDeleteRequest = false
    private lazy var cachedStatusBarImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "菜单栏", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()

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
        if Self.hasPendingPermanentDeleteRequests {
            shouldSuppressInitialWindow = true
        }

        settingsModel.onDisplayModeDidChange = { [weak self] mode in
            self?.applyDisplayMode(mode)
        }
        applyDisplayMode(settingsModel.displayMode)
        if let completedUpdateVersion = SoftwareUpdateCompletionStore.consumeVersion() {
            showMainWindow()
            DispatchQueue.main.async { [weak self] in
                self?.presentCompletedUpdateAlert(version: completedUpdateVersion)
            }
        } else if shouldSuppressInitialWindow {
            logger.info("Suppressed initial window for silent login launch")
        } else {
            scheduleInitialWindowPresentation()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isHandlingPermanentDeleteRequest,
              !Self.hasPendingPermanentDeleteRequests else {
            logger.info("Suppressed settings window while handling permanent deletion")
            return false
        }

        if !flag {
            showMainWindow()
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handleIncomingURL(_:))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window else {
            return
        }

        // The settings UI contains many material-backed views. Release the
        // hosting tree while the app continues running in the background.
        closingWindow.contentView = nil
        closingWindow.delegate = nil
        window = nil
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
                statusItem = item
                configureStatusItem(item)
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
        cachedStatusBarImage
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

        let fileTypesItem = NSMenuItem(title: "新建文件类型", action: nil, keyEquivalent: "")
        let fileTypesMenu = NSMenu()
        for type in quickDocFileTypes {
            fileTypesMenu.addItem(persistentToggleMenuItem(
                title: type.title,
                isOn: settingsModel.enabledFileTypes.contains(type.id)
            ) { [weak self] enabled in
                self?.settingsModel.setFileType(type.id, enabled: enabled)
            })
        }
        fileTypesItem.submenu = fileTypesMenu
        menu.addItem(fileTypesItem)

        let otherFeaturesItem = NSMenuItem(title: "其他功能", action: nil, keyEquivalent: "")
        let otherFeaturesMenu = NSMenu()

        otherFeaturesMenu.addItem(persistentToggleMenuItem(
            title: "终端直达",
            isOn: settingsModel.terminalDirectEnabled
        ) { [weak self] enabled in
            self?.settingsModel.terminalDirectEnabled = enabled
        })

        otherFeaturesMenu.addItem(persistentToggleMenuItem(
            title: "路径复制",
            isOn: settingsModel.pathCopyEnabled
        ) { [weak self] enabled in
            self?.settingsModel.pathCopyEnabled = enabled
        })

        otherFeaturesMenu.addItem(persistentToggleMenuItem(
            title: "快捷操作",
            isOn: settingsModel.quickActionsEnabled
        ) { [weak self] enabled in
            self?.settingsModel.quickActionsEnabled = enabled
        })

        otherFeaturesMenu.addItem(persistentToggleMenuItem(
            title: "展开快捷操作",
            isOn: settingsModel.quickActionsExpanded
        ) { [weak self] enabled in
            self?.settingsModel.quickActionsExpanded = enabled
        })

        otherFeaturesItem.submenu = otherFeaturesMenu
        menu.addItem(otherFeaturesItem)

        let launchAtLoginItem = NSMenuItem(title: "开机自启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = settingsModel.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)

        let silentLaunchAtLoginItem = NSMenuItem(title: "静默启动", action: #selector(toggleSilentLaunchAtLogin(_:)), keyEquivalent: "")
        silentLaunchAtLoginItem.target = self
        silentLaunchAtLoginItem.state = settingsModel.silentLaunchAtLogin ? .on : .off
        silentLaunchAtLoginItem.isEnabled = settingsModel.launchAtLogin
        menu.addItem(silentLaunchAtLoginItem)

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

    private func persistentToggleMenuItem(
        title: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.view = PersistentMenuToggleView(title: title, isOn: isOn, onToggle: onToggle)
        return item
    }

    @objc
    private func handleStatusItemClick(_ sender: Any?) {
        presentStatusMenu()
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
    private func toggleSilentLaunchAtLogin(_ sender: Any?) {
        settingsModel.silentLaunchAtLogin.toggle()
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
        guard url.scheme == "quickdoc" else {
            logger.error("Ignored unsupported URL: \(url.absoluteString, privacy: .public)")
            return
        }

        if url.host == Self.loginLaunchHost {
            guard settingsModel.silentLaunchAtLogin else {
                logger.info("Received login launch request with normal startup enabled")
                return
            }

            shouldSuppressInitialWindow = true
            cancelInitialWindowPresentation()
            logger.info("Received silent login launch request")
            return
        }

        if url.host == Self.permanentDeleteHost {
            isHandlingPermanentDeleteRequest = true
            shouldSuppressInitialWindow = true
            cancelInitialWindowPresentation()
            handlePermanentDeleteRequest(from: url)
            return
        }

        guard url.host == "open-terminal",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedPath = components.queryItems?.first(where: { $0.name == Self.terminalPathQueryKey })?.value,
              let path = encodedPath.removingPercentEncoding else {
            logger.error("Ignored unsupported URL: \(url.absoluteString, privacy: .public)")
            return
        }

        shouldSuppressInitialWindow = true
        cancelInitialWindowPresentation()
        logger.info("Received terminal open request for \(path, privacy: .public)")
        openTerminal(atPath: path)
    }

    private func handlePermanentDeleteRequest(from actionURL: URL) {
        guard let components = URLComponents(url: actionURL, resolvingAgainstBaseURL: false),
              let requestValue = components.queryItems?.first(where: {
                  $0.name == Self.permanentDeleteRequestQueryKey
              })?.value,
              let requestID = UUID(uuidString: requestValue) else {
            logger.error("Ignored malformed permanent deletion request URL")
            presentPermanentDeleteError("删除请求无效，请重试。")
            finishPermanentDeleteRequest()
            return
        }

        let requestURL = Self.permanentDeleteRequestsDirectory
            .appendingPathComponent("\(requestID.uuidString).plist")
        let fileManager = FileManager.default

        do {
            let data = try Data(contentsOf: requestURL)
            try? fileManager.removeItem(at: requestURL)
            guard let payload = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any],
                  let paths = payload["paths"] as? [String] else {
                throw CocoaError(.fileReadCorruptFile)
            }

            var seenPaths = Set<String>()
            let itemURLs = paths.compactMap { path -> URL? in
                guard path.hasPrefix("/") else { return nil }
                let itemURL = URL(fileURLWithPath: path).standardizedFileURL
                guard itemURL.path != "/", seenPaths.insert(itemURL.path).inserted else { return nil }
                return itemURL
            }
            guard itemURLs.count == paths.count, !itemURLs.isEmpty else {
                throw CocoaError(.fileReadInvalidFileName)
            }

            DispatchQueue.main.async { [weak self] in
                self?.presentPermanentDeleteConfirmation(for: itemURLs)
            }
        } catch {
            try? fileManager.removeItem(at: requestURL)
            logger.error("Unable to read permanent deletion request: \(error.localizedDescription, privacy: .public)")
            presentPermanentDeleteError("无法读取删除请求：\(error.localizedDescription)")
            finishPermanentDeleteRequest()
        }
    }

    private func presentPermanentDeleteConfirmation(for itemURLs: [URL]) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = itemURLs.count == 1
            ? "确认彻底删除此项目？"
            : "确认彻底删除这 \(itemURLs.count) 个项目？"

        let visiblePaths = itemURLs.prefix(5).map { "• \($0.path)" }
        let remainingCount = itemURLs.count - visiblePaths.count
        let selectionSummary = visiblePaths.joined(separator: "\n")
            + (remainingCount > 0 ? "\n• 以及另外 \(remainingCount) 个项目" : "")
        alert.informativeText = "这些项目会被立即永久删除，不会移入废纸篓，也无法通过“撤销”恢复。请确认你了解此操作的风险。\n\n\(selectionSummary)"
        alert.alertStyle = .critical

        let deleteButton = alert.addButton(withTitle: "彻底删除")
        deleteButton.hasDestructiveAction = true
        deleteButton.keyEquivalent = ""

        let cancelButton = alert.addButton(withTitle: "取消")
        cancelButton.keyEquivalent = "\r"

        guard alert.runModal() == .alertFirstButtonReturn else {
            logger.info("Permanent deletion cancelled")
            finishPermanentDeleteRequest()
            return
        }

        var failures: [String] = []
        var deletedCount = 0
        for itemURL in itemURLs {
            do {
                try FileManager.default.removeItem(at: itemURL)
                deletedCount += 1
            } catch {
                failures.append("\(itemURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        logger.info("Permanently deleted \(deletedCount) of \(itemURLs.count) requested item(s)")
        if !failures.isEmpty {
            presentPermanentDeleteError("部分项目未能彻底删除：\n\(failures.joined(separator: "\n"))")
        }
        finishPermanentDeleteRequest()
    }

    private func finishPermanentDeleteRequest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isHandlingPermanentDeleteRequest = false
        }
    }

    private func presentPermanentDeleteError(_ message: String) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "QuickDoc"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }

    private static var permanentDeleteRequestsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/QuickDoc/PermanentDeleteRequests", isDirectory: true)
    }

    private static var hasPendingPermanentDeleteRequests: Bool {
        guard let requestFiles = try? FileManager.default.contentsOfDirectory(
            at: permanentDeleteRequestsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        let recentRequestCutoff = Date().addingTimeInterval(-120)
        return requestFiles.contains { requestURL in
            guard requestURL.pathExtension == "plist",
                  let values = try? requestURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modificationDate = values.contentModificationDate else {
                return false
            }
            return modificationDate >= recentRequestCutoff
        }
    }

    private func openTerminal(atPath path: String) {
        let directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            logger.error("Terminal open path does not exist: \(path, privacy: .public)")
            return
        }

        guard let terminalURL = settingsModel.selectedTerminalApplicationURL else {
            logger.error("No terminal application is available")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true

        NSWorkspace.shared.open([directoryURL], withApplicationAt: terminalURL, configuration: configuration) { runningApplication, error in
            if error != nil {
                self.logger.error("Terminal open failed for \(directoryURL.path, privacy: .public) using \(terminalURL.path, privacy: .public)")
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

    private func scheduleInitialWindowPresentation() {
        cancelInitialWindowPresentation()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.shouldSuppressInitialWindow,
                  !self.isHandlingPermanentDeleteRequest,
                  !Self.hasPendingPermanentDeleteRequests else {
                return
            }
            self.showMainWindow()
        }
        initialWindowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func cancelInitialWindowPresentation() {
        initialWindowWorkItem?.cancel()
        initialWindowWorkItem = nil
    }

    private func presentCompletedUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "更新完成"
        alert.informativeText = "QuickDoc 已成功升级到最新版 v\(version)。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
