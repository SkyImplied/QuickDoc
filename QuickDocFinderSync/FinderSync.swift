import Cocoa
import FinderSync
import os

private struct CustomTemplateDefinition {
    let id: String
    let displayName: String
    let fileTypeID: String
    let storedFileName: String
    let isVisibleInContextMenu: Bool

    init?(plist: [String: Any]) {
        guard let id = plist["id"] as? String,
              let displayName = plist["displayName"] as? String,
              let fileTypeID = plist["fileTypeID"] as? String,
              let storedFileName = plist["storedFileName"] as? String,
              !storedFileName.contains("/"),
              storedFileName != ".",
              storedFileName != ".." else {
            return nil
        }

        self.id = id
        self.displayName = displayName
        self.fileTypeID = fileTypeID
        self.storedFileName = storedFileName
        self.isVisibleInContextMenu = plist["isVisibleInContextMenu"] as? Bool ?? true
    }
}

private typealias SharedSettings = (
    enabledFileTypes: [String]?,
    customExtensions: [String]?,
    customTemplates: [CustomTemplateDefinition]?,
    menuOrder: [String]?,
    terminalDirectEnabled: Bool?,
    selectedTerminalAppPath: String?,
    pathCopyEnabled: Bool?,
    quickActionsEnabled: Bool?
)

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.skyimplied.QuickDoc", category: "FinderSync")
    private var menuDefinitionsByTag: [Int: FileDefinition] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private lazy var menuIcon: NSImage = {
        if let image = Self.iconImage(named: "新建文件icon", size: NSSize(width: 18, height: 18)) {
            return image
        }

        let fallback = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件") ?? NSImage()
        fallback.size = NSSize(width: 18, height: 18)
        fallback.isTemplate = true
        return fallback
    }()
    private lazy var toolbarIcon: NSImage = {
        if let image = Self.fixedSizeIcon(named: "工具栏", size: NSSize(width: 18, height: 18), isTemplate: true) {
            return image
        }

        let fallback = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "QuickDoc") ?? NSImage()
        fallback.size = NSSize(width: 18, height: 18)
        fallback.isTemplate = true
        return fallback
    }()
    private lazy var terminalIcon: NSImage = {
        Self.iconImage(named: "终端直达", size: NSSize(width: 18, height: 18))
        ?? NSImage(systemSymbolName: "terminal", accessibilityDescription: "在终端中打开")
        ?? NSImage()
    }()
    private lazy var pathCopyIcon: NSImage = {
        Self.iconImage(named: "文件路径", size: NSSize(width: 18, height: 18))
        ?? NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制当前路径")
        ?? NSImage()
    }()
    private lazy var quickActionsIcon: NSImage = {
        Self.iconImage(named: "快捷操作", size: NSSize(width: 18, height: 18))
        ?? NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "快捷操作")
        ?? NSImage()
    }()
    private var menuItemIconsByID: [String: NSImage] = [:]

    private static let enabledFileTypesKey = "enabledFileTypes"
    private static let customExtensionsKey = "customExtensions"
    private static let customTemplatesKey = "customTemplates"
    private static let menuOrderKey = "menuOrder"
    private static let terminalDirectEnabledKey = "terminalDirectEnabled"
    private static let selectedTerminalAppPathKey = "selectedTerminalAppPath"
    private static let pathCopyEnabledKey = "pathCopyEnabled"
    private static let quickActionsEnabledKey = "quickActionsEnabled"
    private static let diagnosticsEnabled = ProcessInfo.processInfo.environment["QUICKDOC_FINDER_DIAGNOSTICS"] == "1"
    private static let maximumDiagnosticLogSize: UInt64 = 1_000_000
    private static let quickDocCutPasteboardType = NSPasteboard.PasteboardType("com.skyimplied.QuickDoc.cut-files")
    private static let customMenuIDPrefix = "custom."
    private static let finderBundleIdentifier = "com.apple.finder"
    private static let mainAppBundleIdentifier = "com.skyimplied.QuickDoc"
    private static let systemTerminalBundleIdentifier = "com.apple.Terminal"
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
    private static var resourceBundle: Bundle {
        Bundle(for: FinderSync.self)
    }

    private static func monitoredDirectoryURLs() -> [URL] {
        let fileManager = FileManager.default
        let homeURL = URL(fileURLWithPath: "/Users/\(NSUserName())", isDirectory: true)
        let volumesURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        var urls = [
            homeURL,
            homeURL.appendingPathComponent("Desktop", isDirectory: true),
            homeURL.appendingPathComponent("Documents", isDirectory: true),
            homeURL.appendingPathComponent("Downloads", isDirectory: true),
            volumesURL
        ]

        if let mountedVolumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeURLKey],
            options: [.skipHiddenVolumes]
        ) {
            urls.append(contentsOf: mountedVolumes)
        }

        if let volumeChildren = directoryChildren(at: volumesURL) {
            urls.append(contentsOf: volumeChildren)
        }

        var seenPaths = Set<String>()
        return urls.compactMap { url in
            let standardizedURL = url.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  seenPaths.insert(standardizedURL.path).inserted else {
                return nil
            }
            return standardizedURL
        }
    }

    private static func directoryChildren(at directory: URL) -> [URL]? {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return children.filter { child in
            guard let values = try? child.resourceValues(forKeys: resourceKeys),
                  values.isDirectory == true,
                  values.isPackage != true else {
                return false
            }
            return true
        }
    }

    private let builtInDefinitions: [FileDefinition] = [
        FileDefinition(id: "txt", title: "新建 TXT 文件", baseName: "新建 TXT 文件", pathExtension: "txt"),
        FileDefinition(id: "md", title: "新建 Markdown 文件", baseName: "新建 Markdown 文件", pathExtension: "md"),
        FileDefinition(id: "docx", title: "新建 Word 文档", baseName: "新建 Word 文档", pathExtension: "docx", bundledTemplateExtension: "docx"),
        FileDefinition(id: "xlsx", title: "新建 Excel 表格", baseName: "新建 Excel 表格", pathExtension: "xlsx", bundledTemplateExtension: "xlsx"),
        FileDefinition(id: "csv", title: "新建 CSV 表格", baseName: "新建 CSV 表格", pathExtension: "csv", text: "Column A,Column B\n"),
        FileDefinition(id: "pptx", title: "新建 PowerPoint 演示文稿", baseName: "新建 PowerPoint 演示文稿", pathExtension: "pptx", bundledTemplateExtension: "pptx"),
        FileDefinition(id: "json", title: "新建 JSON 文件", baseName: "新建 JSON 文件", pathExtension: "json", text: "{\n  \n}\n"),
        FileDefinition(id: "blank", title: "新建空白文件", baseName: "新建文件", pathExtension: nil),
        FileDefinition(id: "py", title: "新建 Python 文件", baseName: "新建 Python 文件", pathExtension: "py", text: "#!/usr/bin/env python3\n\n"),
        FileDefinition(id: "html", title: "新建 HTML 文件", baseName: "新建 HTML 文件", pathExtension: "html", text: "<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n  <meta charset=\"utf-8\">\n  <title></title>\n</head>\n<body>\n\n</body>\n</html>\n"),
        FileDefinition(id: "sh", title: "新建 Shell 文件", baseName: "新建 Shell 文件", pathExtension: "sh", text: "#!/usr/bin/env bash\n\n", shouldBeExecutable: true),
        FileDefinition(id: "rtf", title: "新建 RTF 文件", baseName: "新建 RTF 文件", pathExtension: "rtf", text: "{\\rtf1\\ansi\\deff0\n}\n")
    ]

    private let defaultEnabledFileTypeIDs: Set<String> = ["txt", "md", "docx", "xlsx", "csv", "pptx", "json", "blank"]

    override init() {
        super.init()
        refreshMonitoredDirectories(reason: "initial load")
        observeMountedVolumeChanges()
        logger.info("QuickDoc Finder Sync extension loaded")
        diagnosticLog("QuickDoc Finder Sync extension loaded")
    }

    deinit {
        workspaceObservers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
    }

    override var toolbarItemName: String {
        "QuickDoc"
    }

    override var toolbarItemToolTip: String {
        "新建文件"
    }

    override var toolbarItemImage: NSImage {
        toolbarIcon
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        refreshMonitoredDirectories(reason: "menu request \(menuKind.rawValue)")
        diagnosticLog("Finder requested menu kind \(menuKind.rawValue)")
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForItems, .toolbarItemMenu:
            return makeNewFileMenu(menuKind: menuKind)
        default:
            return nil
        }
    }

    override func beginObservingDirectory(at url: URL) {
        diagnosticLog("Begin observing directory: \(url.path)")
        refreshMonitoredDirectories(reason: "begin observing \(url.path)")
    }

    private func observeMountedVolumeChanges() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let mountedObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let path = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            self?.refreshMonitoredDirectories(reason: "volume mounted \(path?.path ?? "")")
        }

        let unmountedObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let path = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            self?.refreshMonitoredDirectories(reason: "volume unmounted \(path?.path ?? "")")
        }

        workspaceObservers.append(contentsOf: [mountedObserver, unmountedObserver])
    }

    private func refreshMonitoredDirectories(reason: String) {
        let monitoredURLs = Self.monitoredDirectoryURLs()
        let monitoredURLSet = Set(monitoredURLs)
        let finderSyncController = FIFinderSyncController.default()
        guard finderSyncController.directoryURLs != monitoredURLSet else {
            return
        }

        finderSyncController.directoryURLs = monitoredURLSet
        diagnosticLog("Refreshed monitored directories for \(reason); count=\(monitoredURLs.count); paths=\(monitoredURLs.map(\.path).joined(separator: ", "))")
    }

    private func makeNewFileMenu(menuKind: FIMenuKind) -> NSMenu {
        diagnosticLog("Building Finder menu")
        let menu = NSMenu(title: "QuickDoc")
        menuDefinitionsByTag.removeAll()

        let actionItems = buildActionItems(menuKind: menuKind)
        actionItems.forEach { menu.addItem($0) }

        diagnosticLog("Finder menu contains \(actionItems.count) top-level item(s)")
        return menu
    }

    private func buildActionItems(menuKind: FIMenuKind) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let sharedSettings = readSharedSettings()

        let parent = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        parent.image = menuIcon
        let submenu = NSMenu(title: "新建文件")
        var nextTag = 0

        enabledDefinitions(sharedSettings: sharedSettings).forEach { definition in
            let templates = contextMenuCustomTemplates(for: definition, sharedSettings: sharedSettings)
            if templates.isEmpty {
                addCreateItem(
                    title: definition.title,
                    definition: definition,
                    iconDefinition: definition,
                    to: submenu,
                    nextTag: &nextTag
                )
                return
            }

            let typeItem = NSMenuItem(title: definition.title, action: nil, keyEquivalent: "")
            configureIcon(for: typeItem, definition: definition)

            let templateMenu = NSMenu(title: definition.title)
            addCreateItem(
                title: "空白默认文档",
                definition: definition,
                iconDefinition: definition,
                to: templateMenu,
                nextTag: &nextTag
            )
            templates.forEach { template in
                guard FileManager.default.fileExists(atPath: templateFileURL(for: template).path) else {
                    let missingItem = NSMenuItem(title: "\(template.displayName)（文件缺失）", action: nil, keyEquivalent: "")
                    missingItem.isEnabled = false
                    configureIcon(for: missingItem, definition: definition)
                    templateMenu.addItem(missingItem)
                    diagnosticLog("Custom template file missing: \(template.displayName) -> \(templateFileURL(for: template).path)")
                    return
                }

                let templateDefinition = FileDefinition(
                    id: "template.\(template.id)",
                    title: template.displayName,
                    baseName: template.displayName,
                    pathExtension: definition.pathExtension,
                    templateFileURL: templateFileURL(for: template)
                )
                addCreateItem(
                    title: template.displayName,
                    definition: templateDefinition,
                    iconDefinition: definition,
                    to: templateMenu,
                    nextTag: &nextTag
                )
            }

            typeItem.submenu = templateMenu
            submenu.addItem(typeItem)
        }

        if submenu.items.isEmpty {
            let disabledItem = NSMenuItem(title: "未启用新建文件类型", action: nil, keyEquivalent: "")
            disabledItem.isEnabled = false
            submenu.addItem(disabledItem)
        }

        parent.submenu = submenu
        items.append(parent)

        if settingValue(sharedSettings.terminalDirectEnabled, key: Self.terminalDirectEnabledKey, fallback: true) {
            let terminalItem = NSMenuItem(title: "在终端中打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
            terminalItem.target = self
            terminalItem.image = terminalIcon
            items.append(terminalItem)
        }

        if settingValue(sharedSettings.pathCopyEnabled, key: Self.pathCopyEnabledKey, fallback: true) {
            let pathItem = NSMenuItem(title: "复制当前路径", action: #selector(copyCurrentPath(_:)), keyEquivalent: "")
            pathItem.target = self
            pathItem.image = pathCopyIcon
            items.append(pathItem)
        }

        if settingValue(sharedSettings.quickActionsEnabled, key: Self.quickActionsEnabledKey, fallback: true) {
            items.append(makeQuickActionsMenuItem(menuKind: menuKind))
        }

        return items
    }

    private func makeQuickActionsMenuItem(menuKind: FIMenuKind) -> NSMenuItem {
        let parent = NSMenuItem(title: "快捷操作", action: nil, keyEquivalent: "")
        parent.image = quickActionsIcon

        let submenu = NSMenu(title: "快捷操作")
        let hasSelection = menuKind == .toolbarItemMenu || !selectedItemURLs().isEmpty

        let copyItem = NSMenuItem(title: "拷贝", action: #selector(copySelectedItems(_:)), keyEquivalent: "")
        copyItem.target = self
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "拷贝")
        copyItem.isEnabled = hasSelection
        submenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "粘贴", action: #selector(pasteItems(_:)), keyEquivalent: "")
        pasteItem.target = self
        pasteItem.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "粘贴")
        pasteItem.isEnabled = !pasteboardFileURLs().isEmpty
        submenu.addItem(pasteItem)

        let cutItem = NSMenuItem(title: "剪切", action: #selector(cutSelectedItems(_:)), keyEquivalent: "")
        cutItem.target = self
        cutItem.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "剪切")
        cutItem.isEnabled = hasSelection
        submenu.addItem(cutItem)

        parent.submenu = submenu
        return parent
    }

    private func addCreateItem(
        title: String,
        definition: FileDefinition,
        iconDefinition: FileDefinition,
        to menu: NSMenu,
        nextTag: inout Int
    ) {
        let item = NSMenuItem(title: title, action: #selector(createConfiguredFile(_:)), keyEquivalent: "")
        item.target = self
        item.tag = nextTag
        configureIcon(for: item, definition: iconDefinition)
        menuDefinitionsByTag[nextTag] = definition
        nextTag += 1
        menu.addItem(item)
    }

    private func configureIcon(for item: NSMenuItem, definition: FileDefinition) {
        guard let icon = menuItemIcon(for: definition) else {
            item.image = NSImage(systemSymbolName: "doc", accessibilityDescription: definition.title)
            return
        }

        item.image = icon
    }

    private func menuItemIcon(for definition: FileDefinition) -> NSImage? {
        if let cachedIcon = menuItemIconsByID[definition.id] {
            return cachedIcon
        }

        let resourceName: String?
        if let builtInResourceName = Self.builtInIconResourceNames[definition.id] {
            resourceName = builtInResourceName
        } else if definition.id.hasPrefix(Self.customMenuIDPrefix) {
            resourceName = "空白"
        } else {
            resourceName = nil
        }

        if let resourceName,
           let image = Self.iconImage(named: resourceName, size: NSSize(width: 18, height: 18)) {
            menuItemIconsByID[definition.id] = image
            return image
        }

        diagnosticLog("Using default icon for \(definition.id)")
        return nil
    }

    private static func iconImage(named resourceName: String, size: NSSize) -> NSImage? {
        guard let url = resourceBundle.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = size
        image.isTemplate = false
        return image
    }

    private static func fixedSizeIcon(named resourceName: String, size: NSSize, isTemplate: Bool) -> NSImage? {
        guard let url = resourceBundle.url(forResource: resourceName, withExtension: "png"),
              let sourceImage = NSImage(contentsOf: url) else {
            return nil
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = isTemplate
        return image
    }

    private func enabledDefinitions(sharedSettings: SharedSettings) -> [FileDefinition] {
        let enabledIDs = Set(sharedSettings.enabledFileTypes ?? UserDefaults.standard.stringArray(forKey: Self.enabledFileTypesKey) ?? Array(defaultEnabledFileTypeIDs))
        let builtIns = builtInDefinitions.filter { enabledIDs.contains($0.id) }
        let customDefinitions = (sharedSettings.customExtensions ?? UserDefaults.standard.stringArray(forKey: Self.customExtensionsKey) ?? []).map { fileExtension in
            FileDefinition(
                id: "custom.\(fileExtension)",
                title: "新建 \(fileExtension.uppercased()) 文件",
                baseName: "新建 \(fileExtension.uppercased()) 文件",
                pathExtension: fileExtension
            )
        }

        return orderedDefinitions(builtIns + customDefinitions, menuOrder: sharedSettings.menuOrder)
    }

    private func contextMenuCustomTemplates(for definition: FileDefinition, sharedSettings: SharedSettings) -> [CustomTemplateDefinition] {
        let templates = sharedSettings.customTemplates ?? Self.decodeCustomTemplates(UserDefaults.standard.array(forKey: Self.customTemplatesKey))
        let matchingTemplates = templates.filter { template in
            template.fileTypeID == definition.id && template.isVisibleInContextMenu
        }
        if !matchingTemplates.isEmpty {
            diagnosticLog("Found \(matchingTemplates.count) custom template(s) for \(definition.id)")
        }
        return matchingTemplates
    }

    private func orderedDefinitions(_ definitions: [FileDefinition], menuOrder: [String]?) -> [FileDefinition] {
        guard let menuOrder else { return definitions }

        let definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        let orderedDefinitions = menuOrder.compactMap { definitionsByID[$0] }
        let orderedIDs = Set(orderedDefinitions.map(\.id))
        let remainingDefinitions = definitions.filter { !orderedIDs.contains($0.id) }

        return orderedDefinitions + remainingDefinitions
    }

    private func readSharedSettings() -> SharedSettings {
        for url in Self.sharedSettingsURLs {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                continue
            }

            return (
                payload[Self.enabledFileTypesKey] as? [String],
                payload[Self.customExtensionsKey] as? [String],
                Self.decodeCustomTemplates(payload[Self.customTemplatesKey]),
                payload[Self.menuOrderKey] as? [String],
                payload[Self.terminalDirectEnabledKey] as? Bool,
                payload[Self.selectedTerminalAppPathKey] as? String,
                payload[Self.pathCopyEnabledKey] as? Bool,
                payload[Self.quickActionsEnabledKey] as? Bool
            )
        }

        return (nil, nil, nil, nil, nil, nil, nil, nil)
    }

    private func settingValue(_ sharedValue: Bool?, key: String, fallback: Bool) -> Bool {
        sharedValue ?? UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    private static var sharedSettingsURLs: [URL] {
        let username = NSUserName()
        return [
            URL(fileURLWithPath: "/Users/\(username)")
                .appendingPathComponent("Library/Application Support/QuickDoc/settings.plist"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/QuickDoc/settings.plist")
        ]
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

    private func templateFileURL(for template: CustomTemplateDefinition) -> URL {
        Self.customTemplatesDirectory.appendingPathComponent(template.storedFileName)
    }

    private static func decodeCustomTemplates(_ value: Any?) -> [CustomTemplateDefinition] {
        guard let rawTemplates = value as? [[String: Any]] else { return [] }
        return rawTemplates.compactMap(CustomTemplateDefinition.init(plist:))
    }

    @objc private func createConfiguredFile(_ sender: NSMenuItem) {
        diagnosticLog("Menu action invoked with tag \(sender.tag), title \(sender.title)")

        guard let definition = menuDefinitionsByTag[sender.tag] else {
            logger.error("Create file action invoked without a file definition for tag \(sender.tag)")
            diagnosticLog("Missing file definition for tag \(sender.tag)")
            return
        }
        createFile(from: definition)
    }

    private func createFile(from definition: FileDefinition) {
        logger.info("Create file action invoked for \(definition.id, privacy: .public)")
        diagnosticLog("Create file requested: \(definition.id)")

        guard let directory = targetDirectory() else {
            logger.error("Unable to resolve target directory")
            diagnosticLog("Unable to resolve target directory")
            showError(message: "无法确定目标文件夹。")
            return
        }

        do {
            logger.info("Resolved target directory \(directory.path, privacy: .public)")
            diagnosticLog("Resolved target directory: \(directory.path)")
            let fileURL = try uniqueFileURL(in: directory, definition: definition)
            try definition.contents().write(to: fileURL, options: .withoutOverwriting)
            if definition.shouldBeExecutable {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
            }
            logger.info("Created file at \(fileURL.path, privacy: .public)")
            diagnosticLog("Created file: \(fileURL.path)")
            if !directory.isDesktopDirectory {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        } catch {
            logger.error("Create file failed: \(error.localizedDescription, privacy: .public)")
            diagnosticLog("Create file failed: \(error.localizedDescription)")
            showError(message: "创建文件失败：\(error.localizedDescription)")
        }
    }

    @objc private func openInTerminal(_ sender: NSMenuItem) {
        guard let directory = targetDirectory() else {
            showError(message: "无法确定目标文件夹。")
            return
        }

        openDirectoryInTerminal(directory)
    }

    @objc private func copyCurrentPath(_ sender: NSMenuItem) {
        guard let targetURL = targetURLForPathCopy() else {
            showError(message: "无法确定要复制的路径。")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(targetURL.path, forType: .string)
        diagnosticLog("Copied path: \(targetURL.path)")
    }

    @objc private func copySelectedItems(_ sender: NSMenuItem) {
        writeSelectedItemsToPasteboard(isCut: false)
    }

    @objc private func cutSelectedItems(_ sender: NSMenuItem) {
        writeSelectedItemsToPasteboard(isCut: true)
    }

    private func writeSelectedItemsToPasteboard(isCut: Bool) {
        let selectedURLs = selectedItemURLs()
        guard !selectedURLs.isEmpty else {
            showError(message: "请先选择要\(isCut ? "剪切" : "拷贝")的文件或文件夹。")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(selectedURLs as [NSURL])
        if isCut {
            pasteboard.setString("cut", forType: Self.quickDocCutPasteboardType)
        }
        diagnosticLog("\(isCut ? "Cut" : "Copied") \(selectedURLs.count) item(s)")
    }

    @objc private func pasteItems(_ sender: NSMenuItem) {
        let sourceURLs = pasteboardFileURLs()
        guard !sourceURLs.isEmpty else {
            showError(message: "剪贴板中没有可粘贴的文件或文件夹。")
            return
        }
        guard let directory = targetDirectory() else {
            showError(message: "无法确定粘贴目标文件夹。")
            return
        }

        let shouldMove = NSPasteboard.general.string(forType: Self.quickDocCutPasteboardType) != nil
        var pastedURLs: [URL] = []
        var failures: [String] = []

        for sourceURL in sourceURLs {
            do {
                if shouldMove,
                   sourceURL.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
                    pastedURLs.append(sourceURL)
                    continue
                }

                let destinationURL = uniqueDestinationURL(in: directory, sourceURL: sourceURL)
                if shouldMove {
                    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                } else {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                }
                pastedURLs.append(destinationURL)
            } catch {
                failures.append("\(sourceURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        if shouldMove && failures.isEmpty {
            NSPasteboard.general.clearContents()
        }
        if !pastedURLs.isEmpty && !directory.isDesktopDirectory {
            NSWorkspace.shared.activateFileViewerSelecting(pastedURLs)
        }
        if !failures.isEmpty {
            showError(message: "部分项目粘贴失败：\n\(failures.joined(separator: "\n"))")
        }
        diagnosticLog("\(shouldMove ? "Moved" : "Pasted") \(pastedURLs.count) item(s) into \(directory.path)")
    }

    private func pasteboardFileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return (NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    private func targetURLForPathCopy() -> URL? {
        let finderController = FIFinderSyncController.default()

        if let selectedURL = selectedItemURLs().first {
            return selectedURL
        }

        if let targetedURL = finderController.targetedURL() {
            return directoryURL(for: targetedURL)
        }

        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    private func targetDirectory() -> URL? {
        let finderController = FIFinderSyncController.default()

        if let targetedURL = finderController.targetedURL() {
            return directoryURL(for: targetedURL)
        }

        if let selectedURL = selectedItemURLs().first {
            return directoryURL(for: selectedURL)
        }

        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    private func selectedItemURLs() -> [URL] {
        if let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
           !selectedURLs.isEmpty {
            return selectedURLs.map(\.standardizedFileURL)
        }

        let fallbackURLs = finderSelectionURLsViaAppleScript()
        if !fallbackURLs.isEmpty {
            diagnosticLog("Resolved \(fallbackURLs.count) selected item(s) via Finder AppleScript fallback")
        }
        return fallbackURLs
    }

    private func finderSelectionURLsViaAppleScript() -> [URL] {
        let scriptSource = """
        tell application id "\(Self.finderBundleIdentifier)"
            set selectedItems to selection
            set selectedPaths to {}
            repeat with selectedItem in selectedItems
                try
                    set end of selectedPaths to POSIX path of (selectedItem as alias)
                end try
            end repeat
            return selectedPaths
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            diagnosticLog("Unable to create Finder selection AppleScript")
            return []
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            diagnosticLog("Finder selection AppleScript failed: \(errorInfo)")
            return []
        }

        return Self.stringValues(from: descriptor).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
    }

    private static func stringValues(from descriptor: NSAppleEventDescriptor) -> [String] {
        guard descriptor.descriptorType == typeAEList else {
            return descriptor.stringValue.map { [$0] } ?? []
        }

        guard descriptor.numberOfItems > 0 else {
            return []
        }

        return (1...descriptor.numberOfItems).compactMap { index in
            descriptor.atIndex(index)?.stringValue
        }
    }

    private func directoryURL(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return url
        }

        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }

    private func uniqueDestinationURL(in directory: URL, sourceURL: URL) -> URL {
        let fileManager = FileManager.default
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        var candidate = directory.appendingPathComponent(sourceURL.lastPathComponent)
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let nextName = "\(originalName) \(index)"
            candidate = directory.appendingPathComponent(nextName)
            if !pathExtension.isEmpty {
                candidate.appendPathExtension(pathExtension)
            }
            index += 1
        }

        return candidate
    }

    private func openDirectoryInTerminal(_ directory: URL) {
        guard let terminalURL = terminalApplicationURL(sharedSettings: readSharedSettings()) else {
            showError(message: "未找到可用终端应用。")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = true

        NSWorkspace.shared.open([directory], withApplicationAt: terminalURL, configuration: configuration) { [weak self] runningApplication, error in
            if let error {
                self?.showError(message: "打开终端失败：\(error.localizedDescription)")
                return
            }

            runningApplication?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            self?.diagnosticLog("Opened terminal directly for path: \(directory.path)")
        }
    }

    private func terminalApplicationURL(sharedSettings: SharedSettings) -> URL? {
        if let selectedPath = validTerminalApplicationPath(sharedSettings.selectedTerminalAppPath) {
            return URL(fileURLWithPath: selectedPath, isDirectory: true)
        }

        if let selectedPath = validTerminalApplicationPath(legacySelectedTerminalAppPath()) {
            return URL(fileURLWithPath: selectedPath, isDirectory: true)
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.systemTerminalBundleIdentifier)
    }

    private func validTerminalApplicationPath(_ path: String?) -> String? {
        guard let selectedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedPath.isEmpty,
              FileManager.default.fileExists(atPath: selectedPath) else {
            return nil
        }

        return selectedPath
    }

    private func legacySelectedTerminalAppPath() -> String? {
        let preferencesURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent("\(Self.mainAppBundleIdentifier).plist")

        guard let data = try? Data(contentsOf: preferencesURL),
              let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return payload[Self.selectedTerminalAppPathKey] as? String
    }

    private func uniqueFileURL(in directory: URL, definition: FileDefinition) throws -> URL {
        let fileManager = FileManager.default
        let baseName = sanitizedBaseName(definition.baseName)
        var candidate = directory.appendingPathComponent(baseName)
        if let pathExtension = definition.pathExtension {
            candidate.appendPathExtension(pathExtension)
        }

        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        for index in 2...999 {
            var next = directory.appendingPathComponent("\(baseName) \(index)")
            if let pathExtension = definition.pathExtension {
                next.appendPathExtension(pathExtension)
            }
            if !fileManager.fileExists(atPath: next.path) {
                return next
            }
        }

        throw CocoaError(.fileWriteFileExists)
    }

    private func sanitizedBaseName(_ value: String) -> String {
        var sanitized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }
        return sanitized.isEmpty ? "新建文件" : sanitized
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "QuickDoc"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func diagnosticLog(_ message: String) {
        guard Self.diagnosticsEnabled else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        guard let data = line.data(using: .utf8) else { return }

        for url in Self.diagnosticLogURLs {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: url.path) {
                    try data.write(to: url)
                } else {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    let currentSize = try handle.seekToEnd()
                    if currentSize >= Self.maximumDiagnosticLogSize {
                        try handle.truncate(atOffset: 0)
                    }
                    try handle.write(contentsOf: data)
                }
                return
            } catch {
                continue
            }
        }
    }

    private static var diagnosticLogURLs: [URL] {
        [
            URL(fileURLWithPath: "/Users/\(NSUserName())")
                .appendingPathComponent("Library/Application Support/QuickDoc/finder-sync.log"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/QuickDoc/finder-sync.log")
        ]
    }
}

private extension URL {
    var isDesktopDirectory: Bool {
        let realDesktopPath = "/Users/\(NSUserName())/Desktop"
        return path == realDesktopPath
    }
}

private final class FileDefinition: NSObject {
    let id: String
    let title: String
    let baseName: String
    let pathExtension: String?
    private let bundledTemplateExtension: String?
    private let templateFileURL: URL?
    private let text: String?
    let shouldBeExecutable: Bool

    init(
        id: String,
        title: String,
        baseName: String,
        pathExtension: String?,
        bundledTemplateExtension: String? = nil,
        templateFileURL: URL? = nil,
        text: String? = nil,
        shouldBeExecutable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.baseName = baseName
        self.pathExtension = pathExtension
        self.bundledTemplateExtension = bundledTemplateExtension
        self.templateFileURL = templateFileURL
        self.text = text
        self.shouldBeExecutable = shouldBeExecutable
    }

    func contents() throws -> Data {
        if let templateFileURL {
            return try Data(contentsOf: templateFileURL)
        }

        if let bundledTemplateExtension {
            guard let url = Bundle(for: FileDefinition.self).url(forResource: "blank", withExtension: bundledTemplateExtension) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return try Data(contentsOf: url)
        }

        return text?.data(using: .utf8) ?? Data()
    }
}
