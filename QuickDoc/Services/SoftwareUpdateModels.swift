import Cocoa

enum SoftwareUpdateState: Equatable {
    case idle
    case checking
    case downloading(version: String)
    case preparing(version: String)

    var isWorking: Bool {
        self != .idle
    }

    var buttonTitle: String {
        switch self {
        case .idle:
            return "检查更新"
        case .checking:
            return "正在检查"
        case .downloading:
            return "正在下载"
        case .preparing:
            return "正在安装"
        }
    }

    var statusText: String {
        switch self {
        case .idle:
            return "检查是否有新版本。发现更新后会先询问是否安装，确认后再下载并覆盖旧版本。"
        case .checking:
            return "正在检查是否有新版本..."
        case let .downloading(version):
            return "发现新版本 v\(version)，正在下载安装包..."
        case let .preparing(version):
            return "已下载 v\(version)，正在校验并准备替换当前版本..."
        }
    }
}

struct GitHubRelease {
    let tagName: String
    let assets: [GitHubReleaseAsset]
}

struct GitHubReleaseAsset {
    let name: String
    let downloadURL: URL
}

struct PreparedSoftwareUpdate {
    let rootURL: URL
    let appURL: URL
    let version: String
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
        resolvedURL?.path ?? "未安装"
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

    var errorDescription: String? {
        switch self {
        case .invalidReleaseResponse:
            return "更新服务器返回了无法识别的数据，请稍后重试。"
        case let .invalidReleaseVersion(version):
            return "无法识别最新版本号：\(version)。"
        case .missingZipAsset:
            return "最新版本中没有找到 QuickDoc ZIP 安装包。"
        case .invalidDownloadURL:
            return "更新包下载地址不符合预期，已停止更新。"
        case let .downloadFailed(statusCode):
            return "下载安装包失败，服务器返回状态码 \(statusCode)。"
        case let .extractionFailed(message):
            return "解压安装包失败：\(message)"
        case .missingAppBundle:
            return "安装包中没有找到 QuickDoc.app。"
        case .invalidBundleIdentifier:
            return "安装包不是有效的 QuickDoc 应用，已停止更新。"
        case let .mismatchedBundleVersion(expected, actual):
            return "安装包版本不匹配：预期 v\(expected)，实际为 v\(actual)。"
        case let .invalidCodeSignature(message):
            return "安装包代码签名校验失败：\(message)"
        case .unsupportedInstallLocation:
            return "当前 QuickDoc 位于磁盘映像或临时隔离目录中。请先将应用移动到“应用程序”文件夹，再检查更新。"
        case let .installerLaunchFailed(message):
            return "无法启动更新安装程序：\(message)"
        }
    }
}
