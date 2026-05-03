import Cocoa
import FinderSync
import os

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.skyimplied.QuickDoc", category: "FinderSync")
    private var menuDefinitionsByTag: [Int: FileDefinition] = [:]
    private lazy var menuIcon: NSImage = {
        let image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件") ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
    private var menuItemIconsByID: [String: NSImage] = [:]

    private static let enabledFileTypesKey = "enabledFileTypes"
    private static let customExtensionsKey = "customExtensions"
    private static let menuOrderKey = "menuOrder"
    private static let customMenuIDPrefix = "custom."
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
        let userHomeURL = URL(fileURLWithPath: "/Users/\(NSUserName())", isDirectory: true)
        var urls = [
            userHomeURL,
            URL(fileURLWithPath: "/Volumes", isDirectory: true)
        ]

        let commonUserDirectories = [
            "Desktop",
            "Documents",
            "Downloads",
            "Movies",
            "Music",
            "Pictures"
        ]
        urls.append(contentsOf: commonUserDirectories.map {
            userHomeURL.appendingPathComponent($0, isDirectory: true)
        })

        var seenPaths: Set<String> = []
        return urls.filter { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  !seenPaths.contains(url.path) else {
                return false
            }
            seenPaths.insert(url.path)
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
        let monitoredURLs = Self.monitoredDirectoryURLs()
        FIFinderSyncController.default().directoryURLs = Set(monitoredURLs)
        logger.info("QuickDoc Finder Sync extension loaded")
        diagnosticLog("QuickDoc Finder Sync extension loaded; monitoring \(monitoredURLs.map(\.path).joined(separator: ", "))")
    }

    override var toolbarItemName: String {
        "QuickDoc"
    }

    override var toolbarItemToolTip: String {
        "新建文件"
    }

    override var toolbarItemImage: NSImage {
        menuIcon
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        diagnosticLog("Finder requested menu kind \(menuKind.rawValue)")
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForItems, .toolbarItemMenu:
            return makeNewFileMenu()
        default:
            return nil
        }
    }

    private func makeNewFileMenu() -> NSMenu {
        diagnosticLog("Building Finder menu")
        let menu = NSMenu(title: "QuickDoc")
        let parent = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        parent.image = menuIcon

        let submenu = NSMenu(title: "新建文件")
        menuDefinitionsByTag.removeAll()

        enabledDefinitions().enumerated().forEach { index, definition in
            let item = NSMenuItem(title: definition.title, action: #selector(createConfiguredFile(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            configureIcon(for: item, definition: definition)
            menuDefinitionsByTag[index] = definition
            submenu.addItem(item)
        }

        if submenu.items.isEmpty {
            let disabledItem = NSMenuItem(title: "未启用新建文件类型", action: nil, keyEquivalent: "")
            disabledItem.isEnabled = false
            submenu.addItem(disabledItem)
        }

        parent.submenu = submenu
        menu.addItem(parent)
        diagnosticLog("Finder menu contains \(submenu.items.count) item(s)")
        return menu
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

        if let resourceName = Self.builtInIconResourceNames[definition.id],
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

    private func enabledDefinitions() -> [FileDefinition] {
        let sharedSettings = readSharedSettings()
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

    private func orderedDefinitions(_ definitions: [FileDefinition], menuOrder: [String]?) -> [FileDefinition] {
        guard let menuOrder else { return definitions }

        let definitionsByID = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        let orderedDefinitions = menuOrder.compactMap { definitionsByID[$0] }
        let orderedIDs = Set(orderedDefinitions.map(\.id))
        let remainingDefinitions = definitions.filter { !orderedIDs.contains($0.id) }

        return orderedDefinitions + remainingDefinitions
    }

    private func readSharedSettings() -> (enabledFileTypes: [String]?, customExtensions: [String]?, menuOrder: [String]?) {
        for url in Self.sharedSettingsURLs {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                continue
            }

            return (
                payload[Self.enabledFileTypesKey] as? [String],
                payload[Self.customExtensionsKey] as? [String],
                payload[Self.menuOrderKey] as? [String]
            )
        }

        return (nil, nil, nil)
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
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            logger.error("Create file failed: \(error.localizedDescription, privacy: .public)")
            diagnosticLog("Create file failed: \(error.localizedDescription)")
            showError(message: "创建文件失败：\(error.localizedDescription)")
        }
    }

    private func targetDirectory() -> URL? {
        let finderController = FIFinderSyncController.default()

        if let targetedURL = finderController.targetedURL() {
            return directoryURL(for: targetedURL)
        }

        if let selectedURL = finderController.selectedItemURLs()?.first {
            return directoryURL(for: selectedURL)
        }

        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    private func directoryURL(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return url
        }

        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }

    private func uniqueFileURL(in directory: URL, definition: FileDefinition) throws -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(definition.baseName)
        if let pathExtension = definition.pathExtension {
            candidate.appendPathExtension(pathExtension)
        }

        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        for index in 2...999 {
            var next = directory.appendingPathComponent("\(definition.baseName) \(index)")
            if let pathExtension = definition.pathExtension {
                next.appendPathExtension(pathExtension)
            }
            if !fileManager.fileExists(atPath: next.path) {
                return next
            }
        }

        throw CocoaError(.fileWriteFileExists)
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "QuickDoc"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func diagnosticLog(_ message: String) {
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
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
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

private final class FileDefinition: NSObject {
    let id: String
    let title: String
    let baseName: String
    let pathExtension: String?
    private let bundledTemplateExtension: String?
    private let text: String?
    let shouldBeExecutable: Bool

    init(
        id: String,
        title: String,
        baseName: String,
        pathExtension: String?,
        bundledTemplateExtension: String? = nil,
        text: String? = nil,
        shouldBeExecutable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.baseName = baseName
        self.pathExtension = pathExtension
        self.bundledTemplateExtension = bundledTemplateExtension
        self.text = text
        self.shouldBeExecutable = shouldBeExecutable
    }

    func contents() throws -> Data {
        if let bundledTemplateExtension {
            guard let url = Bundle(for: FileDefinition.self).url(forResource: "blank", withExtension: bundledTemplateExtension) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return try Data(contentsOf: url)
        }

        return text?.data(using: .utf8) ?? Data()
    }
}
