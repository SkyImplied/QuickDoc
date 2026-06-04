import Cocoa

enum SettingsPage: String, CaseIterable, Identifiable {
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

enum QuickDocDisplayMode: String, CaseIterable, Identifiable {
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

struct FileType: Identifiable, Hashable {
    let id: String
    let title: String
    let menuTitle: String
    let pathExtension: String?
    let enabledByDefault: Bool
}

struct MenuPreviewItem: Identifiable, Hashable {
    let id: String
    let title: String
    let templateCount: Int
}

struct CustomTemplate: Identifiable, Hashable {
    let id: String
    var displayName: String
    var fileTypeID: String
    var storedFileName: String
    var originalFileName: String
    var isVisibleInContextMenu: Bool

    var plistRepresentation: [String: Any] {
        [
            "id": id,
            "displayName": displayName,
            "fileTypeID": fileTypeID,
            "storedFileName": storedFileName,
            "originalFileName": originalFileName,
            "isVisibleInContextMenu": isVisibleInContextMenu
        ]
    }

    init(
        id: String,
        displayName: String,
        fileTypeID: String,
        storedFileName: String,
        originalFileName: String,
        isVisibleInContextMenu: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.fileTypeID = fileTypeID
        self.storedFileName = storedFileName
        self.originalFileName = originalFileName
        self.isVisibleInContextMenu = isVisibleInContextMenu
    }

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
        self.originalFileName = plist["originalFileName"] as? String ?? storedFileName
        self.isVisibleInContextMenu = plist["isVisibleInContextMenu"] as? Bool ?? true
    }
}

struct TemplateFileType: Identifiable, Hashable {
    let id: String
    let title: String
    let pathExtension: String
}

enum TemplateMoveDirection {
    case up
    case down
}
