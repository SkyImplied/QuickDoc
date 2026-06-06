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
        guard let url = Bundle.main.url(forResource: "菜单栏", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
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

    private func presentCompletedUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "更新完成"
        alert.informativeText = "QuickDoc 已成功升级到最新版 v\(version)。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
