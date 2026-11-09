import Foundation

enum FinderMenuOrigin: Equatable {
    case container
    case items
    case toolbar
    case other
}

enum FinderMenuBuildPlan: Equatable {
    /// Contextual menus are only requested for monitored directories, where
    /// FIFinderSyncController can already name the folder.
    case rememberFinderSyncTarget
    /// The toolbar menu is built while Finder is blocked in `menu(for:)`.
    /// The front window is resolved after that call returns.
    case deferDirectoryUntilAction
}

enum FinderFrontWindowQuery: Equatable {
    case directory(String)
    case noWindow
    case timeout
    case permissionDenied
    case notADirectory
    case failed
}

enum FinderSelectionQuery: Equatable {
    case paths([String])
    case timeout
    case permissionDenied
    case failed
}

enum FinderDirectoryScriptState: Equatable {
    case noWindow
    case unavailable
    case path(String)
}

enum FinderDirectoryCancelReason: Equatable {
    case noWindow
    case timeout
    case permissionDenied
    case notADirectory
    case unresolved
}

enum FinderDirectoryActionPlan: Equatable {
    case usePath(String)
    case cancel(FinderDirectoryCancelReason)
}

enum FinderSelectionActionPlan: Equatable {
    case usePaths([String])
    case cancel(FinderDirectoryCancelReason)
}

enum FinderPathCopyPlan: Equatable {
    case copyPath(String)
    case cancel(FinderDirectoryCancelReason)
}

enum FinderMenuTargetPolicy {
    /// Short enough that a re-entrant Finder event cannot pin the extension
    /// for the Apple Event Manager's default one-minute timeout.
    static let finderAppleEventTimeoutSeconds = 2

    static func menuBuildPlan(for origin: FinderMenuOrigin) -> FinderMenuBuildPlan {
        switch origin {
        case .toolbar:
            return .deferDirectoryUntilAction
        case .container, .items, .other:
            return .rememberFinderSyncTarget
        }
    }

    static func selectionActionsEnabled(origin: FinderMenuOrigin, finderSyncSelectionCount: Int) -> Bool {
        switch origin {
        case .toolbar:
            // Outside monitored directories Finder Sync reports no selection.
            // The item stays enabled so the action can ask Finder after the
            // menu has been delivered. An empty or failed reply does not act.
            return true
        case .items:
            return finderSyncSelectionCount > 0
        case .container, .other:
            return false
        }
    }

    static func directoryForAction(
        origin: FinderMenuOrigin,
        rememberedPath: String?,
        frontWindow: FinderFrontWindowQuery
    ) -> FinderDirectoryActionPlan {
        switch origin {
        case .toolbar:
            // A Finder Sync URL remembered from a monitored root, usually the
            // home folder, is not a safe stand-in for an unmonitored volume.
            return directoryPlan(from: frontWindow)
        case .container, .items, .other:
            if let rememberedPath, !rememberedPath.isEmpty {
                return .usePath(rememberedPath)
            }
            return .cancel(.unresolved)
        }
    }

    static func selectionForAction(
        origin: FinderMenuOrigin,
        rememberedPaths: [String],
        liveSelection: FinderSelectionQuery,
        directory: FinderFrontWindowQuery,
        currentDirectoryPath: String?
    ) -> FinderSelectionActionPlan {
        switch origin {
        case .toolbar:
            // With no Finder window, `selection` can refer to the Desktop.
            // That is not the window the toolbar command was aimed at.
            if case .noWindow = directory {
                return .cancel(.noWindow)
            }
            switch liveSelection {
            case .paths(let paths):
                let filtered = paths.filter { path in
                    guard let currentDirectoryPath else { return true }
                    return path != currentDirectoryPath
                }
                return .usePaths(filtered)
            case .timeout:
                return .cancel(.timeout)
            case .permissionDenied:
                return .cancel(.permissionDenied)
            case .failed:
                return .cancel(.unresolved)
            }
        case .container, .items, .other:
            return .usePaths(rememberedPaths)
        }
    }

    static func pathCopyPlan(
        selection: FinderSelectionActionPlan,
        directory: FinderDirectoryActionPlan
    ) -> FinderPathCopyPlan {
        switch selection {
        case .cancel(let reason):
            return .cancel(reason)
        case .usePaths(let paths):
            if let first = paths.first, !first.isEmpty {
                return .copyPath(first)
            }
            switch directory {
            case .usePath(let path):
                return .copyPath(path)
            case .cancel(let reason):
                return .cancel(reason)
            }
        }
    }

    static func userMessage(for reason: FinderDirectoryCancelReason, action: String) -> String {
        switch reason {
        case .noWindow:
            return "没有打开的访达窗口，无法\(action)。"
        case .timeout:
            return "访达没有及时响应，已取消\(action)。"
        case .permissionDenied:
            return "没有访达自动化权限，无法\(action)。"
        case .notADirectory:
            return "访达当前目标不是文件夹，已取消\(action)。"
        case .unresolved:
            return "无法确定目标文件夹，已取消\(action)。"
        }
    }

    /// Monitored roots are the home folder and `/Volumes` only. Mount points
    /// under `/Volumes` are excluded because Finder replaces each monitored
    /// root's sidebar icon with the app icon.
    static func monitoredRootPaths(homePath: String) -> [String] {
        [homePath, "/Volumes"]
    }

    static func isSidebarProtectedVolumeMount(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized == "/Volumes" {
            return false
        }
        return standardized.hasPrefix("/Volumes/")
    }

    static func monitoredRootsExcludeProtectedMounts(homePath: String, volumeMounts: [String]) -> Bool {
        let roots = Set(monitoredRootPaths(homePath: homePath).map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        })
        guard roots == Set([URL(fileURLWithPath: homePath).standardizedFileURL.path, "/Volumes"]) else {
            return false
        }
        return volumeMounts.allSatisfy { mount in
            let standardized = URL(fileURLWithPath: mount).standardizedFileURL.path
            return isSidebarProtectedVolumeMount(mount) && !roots.contains(standardized)
        }
    }

    static func frontWindowScript(bundleIdentifier: String) -> String {
        let timeout = finderAppleEventTimeoutSeconds
        return """
        with timeout of \(timeout) seconds
            tell application id "\(bundleIdentifier)"
                set directoryState to "no-window"
                set directoryPath to ""
                if (count of Finder windows) > 0 then
                    set directoryState to "unavailable"
                    try
                        set directoryPath to POSIX path of (target of front Finder window as alias)
                        set directoryState to "ok"
                    on error number errNum
                        if errNum is -1712 then error number errNum
                    end try
                end if
                set selectedPaths to {}
                try
                    set selectedItems to selection
                    repeat with selectedItem in selectedItems
                        try
                            set end of selectedPaths to POSIX path of (selectedItem as alias)
                        on error number errNum
                            if errNum is -1712 then error number errNum
                        end try
                    end repeat
                on error number errNum
                    if errNum is -1712 then error number errNum
                end try
                return {directoryState, directoryPath, selectedPaths}
            end tell
        end timeout
        """
    }

    static func transportFailure(number: Int?) -> (FinderFrontWindowQuery, FinderSelectionQuery) {
        switch number {
        case -1712:
            return (.timeout, .timeout)
        case -1743, -1744:
            return (.permissionDenied, .permissionDenied)
        default:
            return (.failed, .failed)
        }
    }

    static func directoryQuery(state: FinderDirectoryScriptState, pathIsDirectory: Bool) -> FinderFrontWindowQuery {
        switch state {
        case .noWindow:
            return .noWindow
        case .unavailable:
            return .notADirectory
        case .path(let path):
            guard !path.isEmpty, pathIsDirectory else {
                return .notADirectory
            }
            return .directory(path)
        }
    }

    private static func directoryPlan(from query: FinderFrontWindowQuery) -> FinderDirectoryActionPlan {
        switch query {
        case .directory(let path):
            return .usePath(path)
        case .noWindow:
            return .cancel(.noWindow)
        case .timeout:
            return .cancel(.timeout)
        case .permissionDenied:
            return .cancel(.permissionDenied)
        case .notADirectory:
            return .cancel(.notADirectory)
        case .failed:
            return .cancel(.unresolved)
        }
    }
}
