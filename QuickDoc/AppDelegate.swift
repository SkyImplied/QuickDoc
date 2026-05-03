import Cocoa
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showMainWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickDoc"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 820, height: 560)
        window.center()
        window.contentView = NSHostingView(rootView: QuickDocSettingsView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
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
    @StateObject private var model = QuickDocSettingsModel()
    @State private var selection: SettingsPage? = .general

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 262)
                Divider()
                ScrollView {
                    selectedPage
                        .padding(.horizontal, 34)
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollContentBackground(.hidden)
                .background(GlassBackground())
            }

            Color.clear
                .frame(height: 58)
                .contentShape(Rectangle())
                .ifAvailableWindowDragGesture()
        }
        .frame(minWidth: 820, minHeight: 560)
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
            }
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
            PageHeader(title: "通用设置", subtitle: "管理 QuickDoc 的启动行为。")

            GlassSection {
                Toggle("开机自启动", isOn: $model.launchAtLogin)
                Text("登录 macOS 时自动启动 QuickDoc。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
            PageHeader(title: "关于", subtitle: "QuickDoc 为 Finder 右键菜单提供快速新建文件能力。")

            GlassSection {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(radius: 8, y: 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("QuickDoc")
                            .font(.title2.weight(.bold))
                        Text("版本 \(model.appVersion)")
                            .foregroundStyle(.secondary)
                        Text("Finder 右键新建文件工具")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct PermissionStatusCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            HStack(alignment: .center, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("系统扩展权限")
                            .font(.headline)
                        Text("请在 系统设置 > 隐私与安全性 > 登录项与扩展 中启用 QuickDoc 扩展")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.shield")
                }

                Spacer()

                Text("需确认")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.red.opacity(0.12), in: Capsule())

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
    @State private var draggingItemID: String?

    var body: some View {
        GlassSection {
            HStack(spacing: 34) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("访达右键菜单预览")
                            .font(.headline)
                        Text("在 Finder 中右键点击，将显示以下新建文件选项。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "folder")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        if model.menuPreviewItems.isEmpty {
                            PreviewMenuRow(item: MenuPreviewItem(id: "empty", title: "暂无启用的新建类型"), draggable: false)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(model.menuPreviewItems) { item in
                                    PreviewMenuRow(item: item, draggable: true)
                                        .contentShape(Rectangle())
                                        .onDrag {
                                            draggingItemID = item.id
                                            return NSItemProvider(object: item.id as NSString)
                                        }
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: PreviewMenuDropDelegate(
                                                item: item,
                                                draggingItemID: $draggingItemID,
                                                moveAction: model.movePreviewItem
                                            )
                                        )
                                }
                            }
                        }
                    }
                }
                .frame(width: 310, height: 248)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
            }
        }
    }
}

private struct PreviewMenuDropDelegate: DropDelegate {
    let item: MenuPreviewItem
    @Binding var draggingItemID: String?
    let moveAction: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingItemID, draggingItemID != item.id else { return }
        moveAction(draggingItemID, item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItemID = nil
        return true
    }
}

private struct PreviewMenuRow: View {
    let item: MenuPreviewItem
    let draggable: Bool

    var body: some View {
        HStack(spacing: 10) {
            previewIcon
                .frame(width: 18, height: 18)
            Text(item.title)
                .lineLimit(1)
            Spacer()
            if draggable {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 32)
        .padding(.horizontal, 14)
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
    @Published var launchAtLogin: Bool {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

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

    @Published private var menuOrder: [String] {
        didSet {
            UserDefaults.standard.set(menuOrder, forKey: Self.menuOrderKey)
            writeSharedSettings()
        }
    }

    let appVersion: String
    private static let enabledFileTypesKey = "enabledFileTypes"
    private static let customExtensionsKey = "customExtensions"
    private static let menuOrderKey = "menuOrder"

    init() {
        let defaultTypes = quickDocFileTypes.filter(\.enabledByDefault).map(\.id)
        UserDefaults.standard.register(defaults: [
            Self.enabledFileTypesKey: defaultTypes,
            Self.customExtensionsKey: [],
            Self.menuOrderKey: Self.defaultMenuOrder
        ])
        let sharedSettings = Self.readSharedSettings()

        launchAtLogin = SMAppService.mainApp.status == .enabled
        let storedCustomExtensions = sharedSettings.customExtensions ?? UserDefaults.standard.stringArray(forKey: Self.customExtensionsKey) ?? []
        enabledFileTypes = Set(sharedSettings.enabledFileTypes ?? UserDefaults.standard.stringArray(forKey: Self.enabledFileTypesKey) ?? defaultTypes)
        customExtensions = storedCustomExtensions
        menuOrder = Self.normalizedMenuOrder(sharedSettings.menuOrder ?? UserDefaults.standard.stringArray(forKey: Self.menuOrderKey) ?? Self.defaultMenuOrder, customExtensions: storedCustomExtensions)
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        reconcileMenuOrder()
        writeSharedSettings()
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

    func movePreviewItem(_ sourceID: String, before targetID: String) {
        var visibleOrder = menuPreviewItems.map(\.id)
        guard let sourceIndex = visibleOrder.firstIndex(of: sourceID),
              let targetIndex = visibleOrder.firstIndex(of: targetID),
              sourceIndex != targetIndex else {
            return
        }

        let movedID = visibleOrder.remove(at: sourceIndex)
        let adjustedTargetIndex = visibleOrder.firstIndex(of: targetID) ?? targetIndex
        visibleOrder.insert(movedID, at: adjustedTargetIndex)

        let visibleIDs = Set(visibleOrder)
        var updatedVisibleOrder = visibleOrder
        let hiddenOrderedIDs = menuOrder.filter { !visibleIDs.contains($0) }
        updatedVisibleOrder.append(contentsOf: hiddenOrderedIDs)
        menuOrder = Self.normalizedMenuOrder(updatedVisibleOrder, customExtensions: customExtensions)
    }

    func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        do {
            try process.run()
        } catch {
            showAlert(title: "重启 Finder 失败", message: error.localizedDescription)
        }
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
            Self.menuOrderKey: menuOrder
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

    private static func readSharedSettings() -> (enabledFileTypes: [String]?, customExtensions: [String]?, menuOrder: [String]?) {
        guard let data = try? Data(contentsOf: sharedSettingsURL),
              let payload = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (nil, nil, nil)
        }

        return (
            payload[enabledFileTypesKey] as? [String],
            payload[customExtensionsKey] as? [String],
            payload[menuOrderKey] as? [String]
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

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
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
