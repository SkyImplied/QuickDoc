import Cocoa
import FinderSync
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class QuickDocSettingsModel: ObservableObject {
    private struct GitHubReleaseResponse: Decodable {
        let tagName: String
        let body: String?
        let assets: [GitHubReleaseAssetResponse]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case assets
        }
    }

    private struct GitHubReleaseAssetResponse: Decodable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    struct AlertContent {
        let title: String
        let message: String
        let style: NSAlert.Style
    }

    struct ExtensionStatus: Equatable {
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
        didSet {
            guard !isSynchronizingLaunchAtLogin else { return }
            setLaunchAtLogin(launchAtLogin)
        }
    }

    @Published var silentLaunchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(silentLaunchAtLogin, forKey: Self.silentLaunchAtLoginKey)
        }
    }

    @Published private(set) var displayMode: QuickDocDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: Self.displayModeKey)
            onDisplayModeDidChange?(displayMode)
        }
    }

    @Published private(set) var extensionStatus = ExtensionStatus(isConfirmed: false)
    @Published private(set) var isRestartingFinder = false
    @Published private(set) var softwareUpdateState = SoftwareUpdateState.idle

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

    @Published var customTemplates: [CustomTemplate] {
        didSet {
            UserDefaults.standard.set(customTemplates.map(\.plistRepresentation), forKey: Self.customTemplatesKey)
            writeSharedSettings()
        }
    }

    @Published var terminalDirectEnabled: Bool {
        didSet {
            UserDefaults.standard.set(terminalDirectEnabled, forKey: Self.terminalDirectEnabledKey)
            writeSharedSettings()
        }
    }

    @Published private(set) var selectedTerminalAppPath: String {
        didSet {
            UserDefaults.standard.set(selectedTerminalAppPath, forKey: Self.selectedTerminalAppPathKey)
            cachedTerminalApplicationIcon = nil
            cachedTerminalApplicationIconPath = nil
            writeSharedSettings()
        }
    }

    @Published var pathCopyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(pathCopyEnabled, forKey: Self.pathCopyEnabledKey)
            writeSharedSettings()
        }
    }

    @Published var quickActionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quickActionsEnabled, forKey: Self.quickActionsEnabledKey)
            writeSharedSettings()
        }
    }

    @Published var quickActionsExpanded: Bool {
        didSet {
            UserDefaults.standard.set(quickActionsExpanded, forKey: Self.quickActionsExpandedKey)
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
    private var cachedTerminalApplicationIcon: NSImage?
    private var cachedTerminalApplicationIconPath: String?
    private var isSynchronizingLaunchAtLogin = false
    private static let displayModeKey = "displayMode"
    private static let silentLaunchAtLoginKey = "silentLaunchAtLogin"
    private static let terminalDirectEnabledKey = "terminalDirectEnabled"
    private static let selectedTerminalAppPathKey = "selectedTerminalAppPath"
    private static let pathCopyEnabledKey = "pathCopyEnabled"
    private static let quickActionsEnabledKey = "quickActionsEnabled"
    private static let quickActionsExpandedKey = "quickActionsExpanded"
    private static let enabledFileTypesKey = "enabledFileTypes"
    private static let customExtensionsKey = "customExtensions"
    private static let customTemplatesKey = "customTemplates"
    private static let menuOrderKey = "menuOrder"
    private static let bundleIdentifier = "com.skyimplied.QuickDoc"
    private static let loginItemIdentifier = "com.skyimplied.QuickDoc.LoginItem"
    private static let systemTerminalBundleIdentifier = "com.apple.Terminal"
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/SkyImplied/QuickDoc/releases/latest")!
    private static let latestReleaseURL = URL(string: "https://github.com/SkyImplied/QuickDoc/releases/latest")!
    private static let systemTerminalApplication = TerminalApplicationOption(
        title: "系统终端",
        bundleIdentifier: systemTerminalBundleIdentifier,
        path: nil
    )

    init() {
        let defaultTypes = quickDocFileTypes.filter(\.enabledByDefault).map(\.id)
        UserDefaults.standard.register(defaults: [
            Self.displayModeKey: QuickDocDisplayMode.menuBarOnly.rawValue,
            Self.silentLaunchAtLoginKey: false,
            Self.terminalDirectEnabledKey: true,
            Self.selectedTerminalAppPathKey: "",
            Self.pathCopyEnabledKey: true,
            Self.quickActionsEnabledKey: true,
            Self.quickActionsExpandedKey: false,
            Self.enabledFileTypesKey: defaultTypes,
            Self.customExtensionsKey: [],
            Self.customTemplatesKey: [],
            Self.menuOrderKey: Self.defaultMenuOrder
        ])
        let sharedSettings = Self.readSharedSettings()

        launchAtLogin = Self.isLaunchAtLoginEnabled
        silentLaunchAtLogin = UserDefaults.standard.bool(forKey: Self.silentLaunchAtLoginKey)
        displayMode = QuickDocDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: Self.displayModeKey) ?? QuickDocDisplayMode.menuBarOnly.rawValue
        ) ?? .menuBarOnly
        terminalDirectEnabled = sharedSettings.terminalDirectEnabled ?? UserDefaults.standard.object(forKey: Self.terminalDirectEnabledKey) as? Bool ?? true
        selectedTerminalAppPath = UserDefaults.standard.string(forKey: Self.selectedTerminalAppPathKey) ?? ""
        pathCopyEnabled = sharedSettings.pathCopyEnabled ?? UserDefaults.standard.object(forKey: Self.pathCopyEnabledKey) as? Bool ?? true
        quickActionsEnabled = sharedSettings.quickActionsEnabled ?? UserDefaults.standard.object(forKey: Self.quickActionsEnabledKey) as? Bool ?? true
        quickActionsExpanded = sharedSettings.quickActionsExpanded ?? UserDefaults.standard.object(forKey: Self.quickActionsExpandedKey) as? Bool ?? false
        let storedCustomExtensions = sharedSettings.customExtensions ?? UserDefaults.standard.stringArray(forKey: Self.customExtensionsKey) ?? []
        let storedCustomTemplates = sharedSettings.customTemplates
            ?? Self.decodeCustomTemplates(UserDefaults.standard.array(forKey: Self.customTemplatesKey))
        enabledFileTypes = Set(sharedSettings.enabledFileTypes ?? UserDefaults.standard.stringArray(forKey: Self.enabledFileTypesKey) ?? defaultTypes)
        customExtensions = storedCustomExtensions
        customTemplates = Self.normalizedCustomTemplates(storedCustomTemplates, customExtensions: storedCustomExtensions)
        menuOrder = Self.normalizedMenuOrder(sharedSettings.menuOrder ?? UserDefaults.standard.stringArray(forKey: Self.menuOrderKey) ?? Self.defaultMenuOrder, customExtensions: storedCustomExtensions)
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        reconcileMenuOrder()
        writeSharedSettings()
        refreshExtensionStatus()
        observeAppActivation()
        migrateLegacyLaunchAtLoginIfNeeded()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var softwareUpdateButtonTitle: String {
        softwareUpdateState.buttonTitle
    }

    var softwareUpdateStatusText: String {
        softwareUpdateState.statusText
    }

    var isSoftwareUpdateInProgress: Bool {
        softwareUpdateState.isWorking
    }

    var selectedTerminalApplicationURL: URL? {
        selectedTerminalApplication?.resolvedURL
            ?? Self.systemTerminalApplication.resolvedURL
    }

    var selectedTerminalApplicationName: String {
        selectedTerminalApplication?.title ?? "系统终端"
    }

    var selectedTerminalApplicationPathText: String {
        selectedTerminalApplicationURL?.path ?? "未找到可用终端"
    }

    var selectedTerminalApplicationIcon: NSImage {
        let iconPath = selectedTerminalApplicationURL?.path
        if cachedTerminalApplicationIconPath == iconPath,
           let cachedTerminalApplicationIcon {
            return cachedTerminalApplicationIcon
        }

        let icon = selectedTerminalApplication?.icon
            ?? Self.systemTerminalApplication.icon
        cachedTerminalApplicationIconPath = iconPath
        cachedTerminalApplicationIcon = icon
        return icon
    }

    var hasCustomTerminalApplication: Bool {
        !selectedTerminalAppPath.isEmpty
    }

    var menuPreviewItems: [MenuPreviewItem] {
        menuOrder.compactMap { id in
            guard enabledFileTypes.contains(id) || id.hasPrefix(Self.customMenuIDPrefix) else {
                return nil
            }
            return menuItem(for: id)
        }
    }

    var templateFileTypes: [TemplateFileType] {
        let builtInTypes = quickDocFileTypes.compactMap { type -> TemplateFileType? in
            guard enabledFileTypes.contains(type.id),
                  let pathExtension = type.pathExtension else {
                return nil
            }
            return TemplateFileType(id: type.id, title: type.title, pathExtension: pathExtension)
        }

        let customTypes = customExtensions.map { fileExtension in
            TemplateFileType(
                id: Self.customMenuID(for: fileExtension),
                title: "\(fileExtension.uppercased()) (.\(fileExtension))",
                pathExtension: fileExtension
            )
        }

        return builtInTypes + customTypes
    }

    var templateFileTypesWithTemplates: [TemplateFileType] {
        templateFileTypes.filter { type in
            customTemplates.contains { $0.fileTypeID == type.id }
        }
    }

    func customTemplates(for fileTypeID: String) -> [CustomTemplate] {
        customTemplates.filter { $0.fileTypeID == fileTypeID }
    }

    func customTemplateFileExists(_ template: CustomTemplate) -> Bool {
        FileManager.default.fileExists(atPath: Self.templateURL(for: template).path)
    }

    func templateFileTypeID(matchingPathExtension pathExtension: String) -> String? {
        let normalized = normalizeExtension(pathExtension)
        guard !normalized.isEmpty else { return nil }
        return templateFileTypes.first { $0.pathExtension == normalized }?.id
    }

    func menuTitle(forTemplateFileTypeID fileTypeID: String) -> String? {
        if let builtIn = quickDocFileTypes.first(where: { $0.id == fileTypeID }) {
            return builtIn.menuTitle
        }

        guard fileTypeID.hasPrefix(Self.customMenuIDPrefix) else { return nil }
        let fileExtension = String(fileTypeID.dropFirst(Self.customMenuIDPrefix.count))
        guard customExtensions.contains(fileExtension) else { return nil }
        return "新建 \(fileExtension.uppercased()) 文件"
    }

    func chooseTerminalApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择终端 App"
        panel.message = "请选择一个可打开文件夹的终端应用。"
        panel.prompt = "选择"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        guard url.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: url.path) else {
            showAlert(title: "无法选择终端", message: "请选择有效的 macOS 应用。")
            return
        }

        selectedTerminalAppPath = url.path
    }

    func resetTerminalApplication() {
        selectedTerminalAppPath = ""
    }

    private var selectedTerminalApplication: TerminalApplicationOption? {
        if selectedTerminalAppPath.isEmpty {
            return Self.systemTerminalApplication
        }

        guard FileManager.default.fileExists(atPath: selectedTerminalAppPath) else {
            return nil
        }

        return Self.terminalApplicationOption(for: URL(fileURLWithPath: selectedTerminalAppPath, isDirectory: true))
    }

    private static func terminalApplicationOption(for url: URL) -> TerminalApplicationOption {
        let bundle = Bundle(url: url)
        let displayName = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle?.localizedInfoDictionary?["CFBundleName"] as? String
            ?? bundle?.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        return TerminalApplicationOption(
            title: displayName,
            bundleIdentifier: bundle?.bundleIdentifier,
            path: url.path
        )
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
        let removedTemplateFileTypeID = Self.customMenuID(for: value)
        customTemplates
            .filter { $0.fileTypeID == removedTemplateFileTypeID }
            .forEach { try? FileManager.default.removeItem(at: Self.templateURL(for: $0)) }
        customExtensions.removeAll { $0 == value }
        customTemplates.removeAll { $0.fileTypeID == removedTemplateFileTypeID }
    }

    func addCustomTemplate(
        from sourceURL: URL,
        displayName: String,
        fileTypeID: String,
        isVisibleInContextMenu: Bool
    ) -> Bool {
        let normalizedName = normalizeTemplateDisplayName(displayName)
        guard !normalizedName.isEmpty else {
            showAlert(title: "无法添加模板", message: "请输入模板在右键菜单里显示的名称。")
            return false
        }

        guard let fileType = templateFileTypes.first(where: { $0.id == fileTypeID }) else {
            showAlert(title: "无法添加模板", message: "请选择要关联的文件类型。")
            return false
        }

        let sourceExtension = normalizeExtension(sourceURL.pathExtension)
        guard sourceExtension == fileType.pathExtension else {
            showAlert(
                title: "模板类型不匹配",
                message: "当前文件是 .\(sourceExtension.isEmpty ? "无后缀" : sourceExtension)，请选择 .\(fileType.pathExtension) 文件，或改关联到匹配的文件类型。"
            )
            return false
        }

        do {
            let templateID = UUID().uuidString
            let storedFileName = "\(templateID).\(fileType.pathExtension)"
            let destinationURL = Self.customTemplatesDirectory.appendingPathComponent(storedFileName)
            try FileManager.default.createDirectory(at: Self.customTemplatesDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            customTemplates.append(CustomTemplate(
                id: templateID,
                displayName: normalizedName,
                fileTypeID: fileTypeID,
                storedFileName: storedFileName,
                originalFileName: sourceURL.lastPathComponent,
                isVisibleInContextMenu: isVisibleInContextMenu
            ))
            return true
        } catch {
            showAlert(title: "添加模板失败", message: error.localizedDescription)
            return false
        }
    }

    func setCustomTemplate(_ templateID: String, visibleInContextMenu: Bool) {
        guard let index = customTemplates.firstIndex(where: { $0.id == templateID }) else { return }
        customTemplates[index].isVisibleInContextMenu = visibleInContextMenu
    }

    func renameCustomTemplate(_ templateID: String) {
        guard let index = customTemplates.firstIndex(where: { $0.id == templateID }) else { return }

        let alert = NSAlert()
        alert.messageText = "重命名模板"
        alert.informativeText = "请输入此模板在 Finder 右键菜单中的显示名称。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.stringValue = customTemplates[index].displayName
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let normalizedName = normalizeTemplateDisplayName(textField.stringValue)
        guard !normalizedName.isEmpty else {
            showAlert(title: "无法重命名模板", message: "显示名称不能为空。")
            return
        }

        customTemplates[index].displayName = normalizedName
    }

    func removeCustomTemplate(_ templateID: String) {
        guard let template = customTemplates.first(where: { $0.id == templateID }) else { return }

        let alert = NSAlert()
        alert.messageText = "删除模板"
        alert.informativeText = "删除“\(template.displayName)”后，它将不再显示在右键菜单中，已保存的模板副本也会被移除。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        try? FileManager.default.removeItem(at: Self.templateURL(for: template))
        customTemplates.removeAll { $0.id == templateID }
    }

    func canMoveCustomTemplate(_ templateID: String, direction: TemplateMoveDirection) -> Bool {
        guard let template = customTemplates.first(where: { $0.id == templateID }) else { return false }
        let group = customTemplates(for: template.fileTypeID)
        guard let groupIndex = group.firstIndex(where: { $0.id == templateID }) else { return false }

        switch direction {
        case .up:
            return groupIndex > 0
        case .down:
            return groupIndex < group.count - 1
        }
    }

    func moveCustomTemplate(_ templateID: String, direction: TemplateMoveDirection) {
        guard let template = customTemplates.first(where: { $0.id == templateID }) else { return }
        let group = customTemplates(for: template.fileTypeID)
        guard let groupIndex = group.firstIndex(where: { $0.id == templateID }) else { return }

        let targetGroupIndex: Int
        switch direction {
        case .up:
            targetGroupIndex = groupIndex - 1
        case .down:
            targetGroupIndex = groupIndex + 1
        }

        guard group.indices.contains(targetGroupIndex),
              let sourceIndex = customTemplates.firstIndex(where: { $0.id == templateID }),
              let targetIndex = customTemplates.firstIndex(where: { $0.id == group[targetGroupIndex].id }) else {
            return
        }

        customTemplates.swapAt(sourceIndex, targetIndex)
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
        let refreshedStatus = ExtensionStatus(isConfirmed: FIFinderSyncController.isExtensionEnabled)
        guard refreshedStatus != extensionStatus else { return }
        extensionStatus = refreshedStatus
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

    func checkForSoftwareUpdate() {
        guard !softwareUpdateState.isWorking else { return }
        softwareUpdateState = .checking

        Task {
            do {
                try await checkForSoftwareUpdateWorkflow()
            } catch {
                softwareUpdateState = .idle
                showAlert(title: "检查更新失败", message: error.localizedDescription)
            }
        }
    }

    func showLanguageComingSoon(languageName: String) {
        showAlert(
            title: "功能等待未来更新",
            message: "\(languageName) 语言支持正在规划中，当前版本暂未开放，敬请期待后续版本更新。"
        )
    }

    func showFeatureComingSoon(featureName: String) {
        showAlert(
            title: "功能等待未来更新",
            message: "\(featureName) 功能正在规划中，当前版本暂未开放，敬请期待后续版本更新。"
        )
    }

    private func checkForSoftwareUpdateWorkflow() async throws {
        let release = try await fetchLatestRelease()
        guard let latestVersion = Self.normalizedVersion(release.tagName) else {
            throw SoftwareUpdateError.invalidReleaseVersion(release.tagName)
        }

        guard Self.isVersion(latestVersion, newerThan: appVersion) else {
            softwareUpdateState = .idle
            showAlert(
                title: "已是最新版本",
                message: "当前安装的 QuickDoc v\(appVersion) 已经是最新版本。"
            )
            return
        }

        guard confirmSoftwareUpdate(version: latestVersion, releaseNotes: release.body) else {
            softwareUpdateState = .idle
            return
        }

        guard let asset = release.assets.first(where: { asset in
            asset.name.lowercased().hasPrefix("quickdoc-")
                && asset.name.lowercased().hasSuffix(".zip")
        }) else {
            throw SoftwareUpdateError.missingZipAsset
        }

        softwareUpdateState = .downloading(version: latestVersion)
        let preparedUpdate = try await downloadAndPrepareUpdate(asset: asset, version: latestVersion)
        softwareUpdateState = .preparing(version: latestVersion)

        do {
            try scheduleSoftwareUpdateInstallation(preparedUpdate)
        } catch {
            try? FileManager.default.removeItem(at: preparedUpdate.rootURL)
            throw error
        }
    }

    private func confirmSoftwareUpdate(version: String, releaseNotes: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(version)"
        alert.informativeText = "是否立即下载并安装新版本？确认后 QuickDoc 会自动下载更新，在替换完成后重新打开并提示升级成功。"
        alert.alertStyle = .informational
        alert.accessoryView = releaseNotesAccessoryView(version: version, releaseNotes: releaseNotes)
        alert.addButton(withTitle: "确认更新")
        alert.addButton(withTitle: "暂不更新")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func releaseNotesAccessoryView(version: String, releaseNotes: String) -> NSView {
        let notes = Self.normalizedReleaseNotes(releaseNotes)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 180))
        textView.string = "v\(version) 更新内容\n\n\(notes)"
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        textView.textColor = .labelColor
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 460, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 180))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        return scrollView
    }

    private static func normalizedReleaseNotes(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return "此版本暂未填写发布说明。"
        }

        return String(normalized.prefix(4_000))
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        do {
            return try await fetchLatestReleaseFromAPI()
        } catch {
            return try await fetchLatestReleaseFromRedirect()
        }
    }

    private func fetchLatestReleaseFromAPI() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseAPIURL)
        request.setValue("QuickDoc/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SoftwareUpdateError.invalidReleaseResponse
        }

        let apiRelease: GitHubReleaseResponse
        do {
            apiRelease = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        } catch {
            throw SoftwareUpdateError.invalidReleaseResponse
        }

        return GitHubRelease(
            tagName: apiRelease.tagName,
            body: apiRelease.body ?? "",
            assets: apiRelease.assets.map {
                GitHubReleaseAsset(name: $0.name, downloadURL: $0.downloadURL)
            }
        )
    }

    private func fetchLatestReleaseFromRedirect() async throws -> GitHubRelease {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("QuickDoc/\(appVersion)", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let resolvedURL = httpResponse.url,
              resolvedURL.host == "github.com",
              resolvedURL.path.contains("/SkyImplied/QuickDoc/releases/tag/") else {
            throw SoftwareUpdateError.invalidReleaseResponse
        }

        let tagName = resolvedURL.lastPathComponent
        guard let version = Self.normalizedVersion(tagName),
              let downloadURL = URL(
                string: "https://github.com/SkyImplied/QuickDoc/releases/download/\(tagName)/QuickDoc-\(version).zip"
              ) else {
            throw SoftwareUpdateError.invalidReleaseVersion(tagName)
        }

        return GitHubRelease(
            tagName: tagName,
            body: "",
            assets: [GitHubReleaseAsset(name: "QuickDoc-\(version).zip", downloadURL: downloadURL)]
        )
    }

    private func downloadAndPrepareUpdate(asset: GitHubReleaseAsset, version: String) async throws -> PreparedSoftwareUpdate {
        guard asset.downloadURL.scheme == "https",
              asset.downloadURL.host == "github.com" else {
            throw SoftwareUpdateError.invalidDownloadURL
        }

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickDocUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

            var request = URLRequest(url: asset.downloadURL)
            request.setValue("QuickDoc/\(appVersion)", forHTTPHeaderField: "User-Agent")
            let (downloadURL, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw SoftwareUpdateError.downloadFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
            }

            let archiveURL = rootURL.appendingPathComponent(asset.name)
            try FileManager.default.moveItem(at: downloadURL, to: archiveURL)

            let extractedURL = rootURL.appendingPathComponent("extracted", isDirectory: true)
            try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
            let extractResult = await runProcess(
                executablePath: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, extractedURL.path]
            )
            guard extractResult.exitCode == 0 else {
                throw SoftwareUpdateError.extractionFailed(
                    extractResult.errorDescription ?? "ditto 返回了退出码 \(extractResult.exitCode)。"
                )
            }

            let appURL = extractedURL.appendingPathComponent("QuickDoc.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                throw SoftwareUpdateError.missingAppBundle
            }

            try await validatePreparedUpdate(at: appURL, expectedVersion: version)
            return PreparedSoftwareUpdate(rootURL: rootURL, appURL: appURL, version: version)
        } catch {
            try? FileManager.default.removeItem(at: rootURL)
            throw error
        }
    }

    private func validatePreparedUpdate(at appURL: URL, expectedVersion: String) async throws {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        guard let payload = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              payload["CFBundleIdentifier"] as? String == Self.bundleIdentifier else {
            throw SoftwareUpdateError.invalidBundleIdentifier
        }

        let actualVersion = payload["CFBundleShortVersionString"] as? String ?? ""
        guard actualVersion == expectedVersion else {
            throw SoftwareUpdateError.mismatchedBundleVersion(expected: expectedVersion, actual: actualVersion)
        }

        let verifyResult = await runProcess(
            executablePath: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", appURL.path]
        )
        guard verifyResult.exitCode == 0 else {
            throw SoftwareUpdateError.invalidCodeSignature(
                verifyResult.errorDescription ?? "codesign 返回了退出码 \(verifyResult.exitCode)。"
            )
        }
    }

    private func scheduleSoftwareUpdateInstallation(_ update: PreparedSoftwareUpdate) throws {
        let installedAppURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard !installedAppURL.path.hasPrefix("/Volumes/"),
              !installedAppURL.path.contains("/AppTranslocation/") else {
            throw SoftwareUpdateError.unsupportedInstallLocation
        }

        let scriptURL = update.rootURL.appendingPathComponent("install-update.sh")
        try Self.installerScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let arguments = [
            scriptURL.path,
            installedAppURL.path,
            update.appURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            update.rootURL.path,
            SoftwareUpdateCompletionStore.markerURL.path,
            update.version
        ]
        let parentURL = installedAppURL.deletingLastPathComponent()
        let installer = Process()

        if FileManager.default.isWritableFile(atPath: parentURL.path) {
            installer.executableURL = URL(fileURLWithPath: "/bin/sh")
            installer.arguments = arguments
        } else {
            let command = (["/bin/sh"] + arguments)
                .map(Self.shellQuoted(_:))
                .joined(separator: " ")
            installer.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            installer.arguments = [
                "-e",
                "do shell script \(Self.appleScriptQuoted(command)) with administrator privileges"
            ]
        }

        do {
            try installer.run()
        } catch {
            throw SoftwareUpdateError.installerLaunchFailed(error.localizedDescription)
        }

        NSApp.terminate(nil)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try registerLoginItemIfNeeded()
                try unregisterLegacyLaunchAtLoginIfPossible()
            } else {
                try unregisterLoginItemIfNeeded()
                try unregisterServiceIfNeeded(SMAppService.mainApp)
            }
        } catch {
            synchronizeLaunchAtLoginStatus()
            showAlert(title: "开机自启动设置失败", message: error.localizedDescription)
        }
    }

    private func migrateLegacyLaunchAtLoginIfNeeded() {
        guard SMAppService.mainApp.status == .enabled else { return }

        do {
            try registerLoginItemIfNeeded()
            try unregisterLegacyLaunchAtLoginIfPossible()
            synchronizeLaunchAtLoginStatus()
        } catch {
            showAlert(title: "开机自启动升级失败", message: error.localizedDescription)
        }
    }

    private func registerLoginItemIfNeeded() throws {
        let service = Self.loginItemService
        guard service.status == .notRegistered || service.status == .notFound else { return }
        try service.register()
    }

    private func unregisterLegacyLaunchAtLoginIfPossible() throws {
        guard Self.loginItemService.status == .enabled else { return }
        try unregisterServiceIfNeeded(SMAppService.mainApp)
    }

    private func unregisterLoginItemIfNeeded() throws {
        try unregisterServiceIfNeeded(Self.loginItemService)
    }

    private func unregisterServiceIfNeeded(_ service: SMAppService) throws {
        guard service.status != .notRegistered, service.status != .notFound else { return }
        try service.unregister()
    }

    private func synchronizeLaunchAtLoginStatus() {
        isSynchronizingLaunchAtLogin = true
        launchAtLogin = Self.isLaunchAtLoginEnabled
        isSynchronizingLaunchAtLogin = false
    }

    private static var loginItemService: SMAppService {
        SMAppService.loginItem(identifier: loginItemIdentifier)
    }

    private static var isLaunchAtLoginEnabled: Bool {
        loginItemService.status == .enabled || SMAppService.mainApp.status == .enabled
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

    private static func normalizedVersion(_ value: String) -> String? {
        var version = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.lowercased().hasPrefix("v") {
            version.removeFirst()
        }
        version = String(version.split(separator: "-", maxSplits: 1).first ?? "")

        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        return components.joined(separator: ".")
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard let candidate = normalizedVersion(candidate),
              let current = normalizedVersion(current) else {
            return candidate.compare(current, options: .numeric) == .orderedDescending
        }

        var candidateComponents = candidate.split(separator: ".").compactMap { Int($0) }
        var currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let componentCount = max(candidateComponents.count, currentComponents.count)

        candidateComponents.append(contentsOf: repeatElement(0, count: componentCount - candidateComponents.count))
        currentComponents.append(contentsOf: repeatElement(0, count: componentCount - currentComponents.count))

        for index in 0..<componentCount where candidateComponents[index] != currentComponents[index] {
            return candidateComponents[index] > currentComponents[index]
        }

        return false
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedValue)\""
    }

    private static let installerScript = """
    #!/bin/sh
    set -u

    target_app="$1"
    source_app="$2"
    old_pid="$3"
    cleanup_root="$4"
    update_marker="$5"
    installed_version="$6"
    parent_dir="$(/usr/bin/dirname "$target_app")"
    incoming_app="$parent_dir/.QuickDoc.update-$$.app"
    backup_app="$parent_dir/.QuickDoc.backup-$$.app"
    lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

    show_failure() {
      if [ -e "$backup_app" ] && [ ! -e "$target_app" ]; then
        /bin/mv "$backup_app" "$target_app" >/dev/null 2>&1 || true
      fi
      /usr/bin/open -R "$source_app" >/dev/null 2>&1 || true
      /usr/bin/osascript -e 'display alert "QuickDoc 更新失败" message "自动替换没有完成，旧版本已保留。请在 Finder 中手动替换应用。"' >/dev/null 2>&1 || true
      exit 1
    }

    while /bin/kill -0 "$old_pid" >/dev/null 2>&1; do
      /bin/sleep 0.2
    done

    /usr/bin/pkill -x QuickDocFinderSync >/dev/null 2>&1 || true
    /bin/rm -rf "$incoming_app" "$backup_app"
    /usr/bin/ditto "$source_app" "$incoming_app" || show_failure

    if [ -e "$target_app" ]; then
      /bin/mv "$target_app" "$backup_app" || show_failure
    fi

    if /bin/mv "$incoming_app" "$target_app"; then
      /bin/rm -rf "$backup_app"
      "$lsregister" -f -R -trusted "$target_app" >/dev/null 2>&1 || true
      /bin/mkdir -p "$(/usr/bin/dirname "$update_marker")" >/dev/null 2>&1 || true
      /usr/bin/printf '%s\n' "$installed_version" > "$update_marker" 2>/dev/null || true
      /usr/bin/open -n "$target_app"
      /bin/rm -rf "$cleanup_root"
      exit 0
    fi

    show_failure
    """

    private func normalizeExtension(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasPrefix(".") {
            normalized.removeFirst()
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-+")
        normalized = String(normalized.unicodeScalars.filter { allowed.contains($0) })
        return String(normalized.prefix(24))
    }

    private func normalizeTemplateDisplayName(_ value: String) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }
        return String(normalized.prefix(80))
    }

    private func writeSharedSettings() {
        let payload: [String: Any] = [
            Self.enabledFileTypesKey: Array(enabledFileTypes),
            Self.customExtensionsKey: customExtensions,
            Self.customTemplatesKey: customTemplates.map(\.plistRepresentation),
            Self.menuOrderKey: menuOrder,
            Self.terminalDirectEnabledKey: terminalDirectEnabled,
            Self.selectedTerminalAppPathKey: selectedTerminalAppPath,
            Self.pathCopyEnabledKey: pathCopyEnabled,
            Self.quickActionsEnabledKey: quickActionsEnabled,
            Self.quickActionsExpandedKey: quickActionsExpanded
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

    private static func readSharedSettings() -> (
        enabledFileTypes: [String]?,
        customExtensions: [String]?,
        customTemplates: [CustomTemplate]?,
        menuOrder: [String]?,
        terminalDirectEnabled: Bool?,
        selectedTerminalAppPath: String?,
        pathCopyEnabled: Bool?,
        quickActionsEnabled: Bool?,
        quickActionsExpanded: Bool?
    ) {
        guard let data = try? Data(contentsOf: sharedSettingsURL),
              let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (nil, nil, nil, nil, nil, nil, nil, nil, nil)
        }

        return (
            payload[enabledFileTypesKey] as? [String],
            payload[customExtensionsKey] as? [String],
            decodeCustomTemplates(payload[customTemplatesKey]),
            payload[menuOrderKey] as? [String],
            payload[terminalDirectEnabledKey] as? Bool,
            payload[selectedTerminalAppPathKey] as? String,
            payload[pathCopyEnabledKey] as? Bool,
            payload[quickActionsEnabledKey] as? Bool,
            payload[quickActionsExpandedKey] as? Bool
        )
    }

    private static var sharedSettingsURL: URL {
        URL(fileURLWithPath: "/Users/\(NSUserName())")
            .appendingPathComponent("Library/Application Support/QuickDoc/settings.plist")
    }

    private static var customTemplatesDirectory: URL {
        sharedSettingsURL
            .deletingLastPathComponent()
            .appendingPathComponent("Templates", isDirectory: true)
    }

    private static func templateURL(for template: CustomTemplate) -> URL {
        customTemplatesDirectory.appendingPathComponent(template.storedFileName)
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

    private static func decodeCustomTemplates(_ value: Any?) -> [CustomTemplate] {
        guard let rawTemplates = value as? [[String: Any]] else { return [] }
        return rawTemplates.compactMap(CustomTemplate.init(plist:))
    }

    private static func normalizedCustomTemplates(_ templates: [CustomTemplate], customExtensions: [String]) -> [CustomTemplate] {
        let supportedIDs = Set(quickDocFileTypes.compactMap { type in
            type.pathExtension == nil ? nil : type.id
        } + customExtensions.map(customMenuID(for:)))

        var seenIDs: Set<String> = []
        return templates.filter { template in
            guard supportedIDs.contains(template.fileTypeID),
                  !template.id.isEmpty,
                  !template.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !template.storedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !seenIDs.contains(template.id) else {
                return false
            }
            seenIDs.insert(template.id)
            return true
        }
    }

    private func reconcileMenuOrder() {
        let normalized = Self.normalizedMenuOrder(menuOrder, customExtensions: customExtensions)
        if normalized != menuOrder {
            menuOrder = normalized
        }
    }

    private func menuItem(for id: String) -> MenuPreviewItem? {
        if let builtIn = quickDocFileTypes.first(where: { $0.id == id }) {
            return MenuPreviewItem(
                id: id,
                title: builtIn.menuTitle,
                templateCount: customTemplates.filter {
                    $0.fileTypeID == id && $0.isVisibleInContextMenu && customTemplateFileExists($0)
                }.count
            )
        }

        guard id.hasPrefix(Self.customMenuIDPrefix) else { return nil }
        let fileExtension = String(id.dropFirst(Self.customMenuIDPrefix.count))
        guard customExtensions.contains(fileExtension) else { return nil }
        return MenuPreviewItem(
            id: id,
            title: "新建 \(fileExtension.uppercased()) 文件",
            templateCount: customTemplates.filter {
                $0.fileTypeID == id && $0.isVisibleInContextMenu && customTemplateFileExists($0)
            }.count
        )
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
