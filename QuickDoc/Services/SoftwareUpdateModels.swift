import Cocoa

enum SoftwareUpdateState: Equatable {
    case idle
    case checking
    case downloading(version: String)
    case verifying(version: String)
    case ready(version: String)
    case failed(version: String)
    case preparing(version: String)

    var isWorking: Bool {
        self != .idle
    }

    var buttonTitle: String {
        switch self {
        case .idle:
            return L("检查更新")
        case .checking:
            return L("正在检查")
        case .downloading, .verifying:
            return L("正在下载")
        case .ready:
            return L("可以开始安装了")
        case .failed:
            return L("重试")
        case .preparing:
            return L("正在安装")
        }
    }

    var statusText: String {
        switch self {
        case .idle:
            return L("检查是否有新版本。")
        case .checking:
            return L("正在检查是否有新版本...")
        case .downloading:
            return L("正在下载更新...")
        case .verifying:
            return L("正在校验更新包...")
        case .ready:
            return L("可以开始安装了")
        case .failed:
            return L("下载更新失败，请检查网络后重试。")
        case .preparing:
            return L("正在安装")
        }
    }
}

enum SoftwareUpdatePanelPhase: Equatable {
    case downloading(received: Int64, expected: Int64)
    case verifying
    case ready
    case failed(String)
    case installing
}

struct GitHubRelease {
    let tagName: String
    let body: String
    let assets: [GitHubReleaseAsset]
}

struct GitHubReleaseAsset {
    let name: String
    let downloadURL: URL
    let digest: String
}

struct PreparedSoftwareUpdate {
    let rootURL: URL
    let appURL: URL
    let version: String
    let byteCount: Int64
}

enum SoftwareUpdateCompletionStore {
    static let markerURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/QuickDoc/update-complete.txt")

    static func consumeVersion() -> String? {
        guard let contents = try? String(contentsOf: markerURL, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: markerURL)

        let version = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }
}

struct TerminalApplicationOption: Identifiable, Equatable {
    let title: String
    let bundleIdentifier: String?
    let path: String?

    var id: String {
        bundleIdentifier ?? path ?? title
    }

    var resolvedURL: URL? {
        if let path, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        if let bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }

        return nil
    }

    var subtitle: String {
        resolvedURL?.path ?? L("未安装")
    }

    var icon: NSImage {
        guard let resolvedURL else {
            return NSImage(systemSymbolName: "terminal", accessibilityDescription: title) ?? NSImage()
        }

        let image = NSWorkspace.shared.icon(forFile: resolvedURL.path)
        image.size = NSSize(width: 30, height: 30)
        return image
    }
}

enum SoftwareUpdateError: LocalizedError {
    case invalidReleaseResponse
    case invalidReleaseVersion(String)
    case missingZipAsset
    case invalidDownloadURL
    case downloadFailed(Int)
    case extractionFailed(String)
    case missingAppBundle
    case invalidBundleIdentifier
    case mismatchedBundleVersion(expected: String, actual: String)
    case invalidCodeSignature(String)
    case unsupportedInstallLocation
    case installerLaunchFailed(String)
    case cancelled
    case missingDigest
    case digestMismatch
    case networkFailed

    var errorDescription: String? {
        switch self {
        case .invalidReleaseResponse:
            return L("更新服务器返回了无法识别的数据，请稍后重试。")
        case let .invalidReleaseVersion(version):
            return LF("无法识别最新版本号：%@。", version)
        case .missingZipAsset:
            return L("最新版本中没有找到 QuickDoc ZIP 安装包。")
        case .invalidDownloadURL:
            return L("更新包下载地址不符合预期，已停止更新。")
        case let .downloadFailed(statusCode):
            return LF("下载安装包失败，服务器返回状态码 %ld。", statusCode)
        case let .extractionFailed(message):
            return LF("解压安装包失败：%@", message)
        case .missingAppBundle:
            return L("安装包中没有找到 QuickDoc.app。")
        case .invalidBundleIdentifier:
            return L("安装包不是有效的 QuickDoc 应用，已停止更新。")
        case let .mismatchedBundleVersion(expected, actual):
            return LF("安装包版本不匹配：预期 v%@，实际为 v%@。", expected, actual)
        case let .invalidCodeSignature(message):
            return LF("安装包代码签名校验失败：%@", message)
        case .unsupportedInstallLocation:
            return L("当前 QuickDoc 位于磁盘映像或临时隔离目录中。请先将应用移动到“应用程序”文件夹，再检查更新。")
        case let .installerLaunchFailed(message):
            return LF("无法启动更新安装程序：%@", message)
        case .cancelled:
            return L("更新已取消。")
        case .missingDigest:
            return L("发布记录没有校验值，已停止更新。")
        case .digestMismatch:
            return L("更新包的校验值与发布记录不一致，已停止安装。")
        case .networkFailed:
            return L("下载更新失败，请检查网络后重试。")
        }
    }

    var isCancellation: Bool {
        if case .cancelled = self { return true }
        return false
    }
}
