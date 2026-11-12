import CryptoKit
import Foundation

var failures: [String] = []
var checks = 0

func expect(_ condition: Bool, _ message: String) {
    checks += 1
    if condition { return }
    failures.append(message)
    fputs("FAIL \(message)\n", stderr)
}

func match(_ error: Error, _ name: String) -> Bool {
    guard let update = error as? SoftwareUpdateError else { return false }
    switch (update, name) {
    case (.networkFailed, "network"), (.cancelled, "cancelled"), (.digestMismatch, "digest"),
         (.invalidBundleIdentifier, "identity"), (.invalidCodeSignature, "signature"),
         (.missingDigest, "missing-digest"):
        return true
    default:
        return false
    }
}

func writePlist(_ url: URL, identifier: String, version: String, executable: String) throws {
    let plist: [String: Any] = [
        "CFBundleIdentifier": identifier,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": "29",
        "CFBundleExecutable": executable,
        "CFBundlePackageType": url.pathExtension == "appex" ? "XPC!" : "APPL",
        "CFBundleName": executable
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: url)
}

func sign(_ url: URL, identifier: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = ["--force", "--sign", "-", "--identifier", identifier, url.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw NSError(domain: "sign", code: Int(process.terminationStatus))
    }
}

func makeFixtureApp(at appURL: URL, version: String, bundleIdentifier: String) throws {
    let fileManager = FileManager.default
    let macOS = appURL.appendingPathComponent("Contents/MacOS")
    let appex = appURL.appendingPathComponent("Contents/PlugIns/QuickDocFinderSync.appex")
    let login = appURL.appendingPathComponent("Contents/Library/LoginItems/QuickDocLoginItem.app")
    try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: appex.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: login.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    for binary in [
        macOS.appendingPathComponent("QuickDoc"),
        appex.appendingPathComponent("Contents/MacOS/QuickDocFinderSync"),
        login.appendingPathComponent("Contents/MacOS/QuickDocLoginItem")
    ] {
        if fileManager.fileExists(atPath: binary.path) {
            try fileManager.removeItem(at: binary)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: "/bin/echo"), to: binary)
    }
    try writePlist(appURL.appendingPathComponent("Contents/Info.plist"), identifier: bundleIdentifier, version: version, executable: "QuickDoc")
    try writePlist(appex.appendingPathComponent("Contents/Info.plist"), identifier: "com.skyimplied.QuickDoc.FinderSync", version: version, executable: "QuickDocFinderSync")
    try writePlist(login.appendingPathComponent("Contents/Info.plist"), identifier: "com.skyimplied.QuickDoc.LoginItem", version: version, executable: "QuickDocLoginItem")
    try sign(login, identifier: "com.skyimplied.QuickDoc.LoginItem")
    try sign(appex, identifier: "com.skyimplied.QuickDoc.FinderSync")
    try sign(appURL, identifier: bundleIdentifier)
}

func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func zipApp(_ appURL: URL, to archive: URL, padding: Data) throws {
    let stage = archive.deletingLastPathComponent().appendingPathComponent("zip-stage-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: appURL, to: stage.appendingPathComponent("QuickDoc.app"))
    try padding.write(to: stage.appendingPathComponent("padding.bin"))
    if FileManager.default.fileExists(atPath: archive.path) {
        try FileManager.default.removeItem(at: archive)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", stage.path, archive.path]
    try process.run()
    process.waitUntilExit()
    try FileManager.default.removeItem(at: stage)
    if process.terminationStatus != 0 {
        throw NSError(domain: "ditto", code: Int(process.terminationStatus))
    }
}

final class LoopbackServer {
    let process = Process()
    let port: UInt16

    init(directory: URL, delay: Double) throws {
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", Self.script]
        process.standardOutput = pipe
        var environment = ProcessInfo.processInfo.environment
        environment["UPDATE_ROOT"] = directory.path
        environment["UPDATE_DELAY"] = String(delay)
        process.environment = environment
        try process.run()
        var buffer = Data()
        while !buffer.contains(10) && buffer.count < 16 {
            let chunk = pipe.fileHandleForReading.readData(ofLength: 1)
            if chunk.isEmpty { break }
            buffer.append(chunk)
        }
        let text = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let parsed = UInt16(text) else {
            process.terminate()
            throw NSError(domain: "server", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
        }
        port = parsed
    }

    func stop() {
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
    }

    private static let script = """
    import os, time
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    root = os.environ["UPDATE_ROOT"]
    delay = float(os.environ.get("UPDATE_DELAY", "0"))
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            data = open(os.path.join(root, "package.zip"), "rb").read()
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            step = 64 * 1024
            for index in range(0, len(data), step):
                self.wfile.write(data[index:index + step])
                self.wfile.flush()
                if delay:
                    time.sleep(delay)
        def log_message(self, format, *args):
            return
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(server.server_address[1], flush=True)
    server.serve_forever()
    """
}

func runInstaller(target: URL, source: URL, cleanup: URL, marker: URL, failAfterBackup: Bool) throws -> Int32 {
    let sleeper = Process()
    sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
    sleeper.arguments = ["30"]
    try sleeper.run()
    let pid = sleeper.processIdentifier
    sleeper.terminate()
    sleeper.waitUntilExit()

    let scriptURL = cleanup.deletingLastPathComponent().appendingPathComponent("install-\(UUID().uuidString).sh")
    try FileManager.default.createDirectory(at: cleanup, withIntermediateDirectories: true)
    try SoftwareUpdateInstaller.script().write(to: scriptURL, atomically: true, encoding: .utf8)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = [
        scriptURL.path, target.path, source.path, String(pid), cleanup.path, marker.path, "9.9.9", "title", "message"
    ]
    var environment = ProcessInfo.processInfo.environment
    environment["QUICKDOC_UPDATE_OPEN"] = "/usr/bin/true"
    environment["QUICKDOC_UPDATE_SKIP_UI"] = "1"
    environment["QUICKDOC_UPDATE_SKIP_LSREGISTER"] = "1"
    if failAfterBackup {
        environment["QUICKDOC_UPDATE_FAIL_AFTER_BACKUP"] = "1"
    }
    process.environment = environment
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

@main
struct SoftwareUpdateTestRunner {
    static func main() async {
        let previousLoopback = SoftwareUpdateDownloadPolicy.allowLoopbackForTesting
        SoftwareUpdateDownloadPolicy.allowLoopbackForTesting = false
        defer { SoftwareUpdateDownloadPolicy.allowLoopbackForTesting = previousLoopback }

        expect(SoftwareUpdateDownloadPolicy.allows(URL(string: "https://github.com/SkyImplied/QuickDoc/releases/download/v1.8.2/QuickDoc-1.8.2.zip")!), "GitHub 发布地址可以下载")
        expect(SoftwareUpdateDownloadPolicy.allows(URL(string: "https://release-assets.githubusercontent.com/package")!), "GitHub 资源跳转可以下载")
        expect(!SoftwareUpdateDownloadPolicy.allows(URL(string: "https://example.com/QuickDoc.zip")!), "其他网站不能作为更新地址")
        expect(!SoftwareUpdateDownloadPolicy.allows(URL(string: "http://127.0.0.1/package.zip")!), "测试开关关闭时不能使用本机地址")
        expect(SoftwareUpdateByteFormat.pair(received: 1_048_576, expected: 2_097_152) == "1.0 MB / 2.0 MB", "进度文字使用已下载和总大小")
        expect(SoftwareUpdateByteFormat.pair(received: 27_682_406, expected: 36_175_872) == "26.4 MB / 34.5 MB", "进度文字保留一位小数")

        let script = SoftwareUpdateInstaller.script()
        expect(!script.contains("pkill"), "安装脚本不使用 pkill")
        expect(!script.contains("pluginkit"), "安装脚本不注销扩展")
        expect(!script.contains("killall"), "安装脚本不使用 killall")
        expect(!script.contains("Finder.app"), "安装脚本不操作 Finder")
        expect(script.contains("QUICKDOC_UPDATE_SKIP_LSREGISTER"), "安装脚本可以在隔离测试里跳过注册")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quickdoc-update-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let app = root.appendingPathComponent("fixture/QuickDoc.app")
            try makeFixtureApp(at: app, version: "9.9.9", bundleIdentifier: "com.skyimplied.QuickDoc")
            try await SoftwareUpdatePackageChecker.validate(
                appURL: app,
                expectedVersion: "9.9.9",
                bundleIdentifier: "com.skyimplied.QuickDoc",
                appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem"
            )
            expect(true, "签名完整的隔离包可以通过校验")

            let wrong = root.appendingPathComponent("wrong-id/QuickDoc.app")
            try makeFixtureApp(at: wrong, version: "9.9.9", bundleIdentifier: "com.example.NotQuickDoc")
            do {
                try await SoftwareUpdatePackageChecker.validate(
                    appURL: wrong,
                    expectedVersion: "9.9.9",
                    bundleIdentifier: "com.skyimplied.QuickDoc",
                    appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                    loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem"
                )
                expect(false, "错误的 bundle id 必须被拒绝")
            } catch {
                expect(match(error, "identity"), "错误的 bundle id 返回身份错误")
            }

            let broken = root.appendingPathComponent("broken/QuickDoc.app")
            try FileManager.default.createDirectory(at: broken.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: app, to: broken)
            let binary = broken.appendingPathComponent("Contents/MacOS/QuickDoc")
            var bytes = try Data(contentsOf: binary)
            bytes[bytes.count / 2] ^= 0x5A
            try bytes.write(to: binary)
            do {
                try await SoftwareUpdatePackageChecker.validate(
                    appURL: broken,
                    expectedVersion: "9.9.9",
                    bundleIdentifier: "com.skyimplied.QuickDoc",
                    appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                    loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem"
                )
                expect(false, "被改动的签名包必须被拒绝")
            } catch {
                expect(match(error, "signature"), "被改动的包返回签名错误")
            }

            let archive = root.appendingPathComponent("server/package.zip")
            try FileManager.default.createDirectory(at: archive.deletingLastPathComponent(), withIntermediateDirectories: true)
            try zipApp(app, to: archive, padding: Data(count: 256 * 1024))
            let digest = "sha256:" + (try sha256(of: archive))
            try SoftwareUpdateChecksum.verify(file: archive, digest: digest)
            expect(true, "正确的 sha256 可以通过")
            do {
                try SoftwareUpdateChecksum.verify(file: archive, digest: "sha256:" + String(repeating: "ab", count: 32))
                expect(false, "错误的 sha256 必须被拒绝")
            } catch {
                expect(match(error, "digest"), "错误的 sha256 返回校验错误")
            }

            SoftwareUpdateDownloadPolicy.allowLoopbackForTesting = true
            let server = try LoopbackServer(directory: archive.deletingLastPathComponent(), delay: 0)
            defer { server.stop() }
            let destination = root.appendingPathComponent("download/package.zip")
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let transfer = SoftwareUpdateTransfer()
            var progressCount = 0
            var sawTotal = false
            let assetURL = URL(string: "http://127.0.0.1:\(server.port)/package.zip")!
            var request = URLRequest(url: assetURL)
            try await transfer.fetch(request: request, destination: destination) { received, expected in
                progressCount += 1
                if expected > 0 && received <= expected { sawTotal = true }
            }
            expect(progressCount > 0 && sawTotal, "本机下载会报告已下载字节和总大小")
            expect(try sha256(of: destination) == String(digest.dropFirst("sha256:".count)), "下载文件和发布校验值一致")

            let preparedRoot = root.appendingPathComponent("prepared", isDirectory: true)
            let prepared = try await SoftwareUpdatePipeline.prepare(
                asset: GitHubReleaseAsset(name: "QuickDoc-9.9.9.zip", downloadURL: assetURL, digest: digest),
                version: "9.9.9",
                bundleIdentifier: "com.skyimplied.QuickDoc",
                appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem",
                rootURL: preparedRoot,
                fetcher: SoftwareUpdateTransfer(),
                progress: { _, _ in },
                onVerify: {}
            )
            expect(prepared.version == "9.9.9" && prepared.byteCount > 0, "校验通过后得到待安装的包")
            expect(FileManager.default.fileExists(atPath: prepared.appURL.path), "待安装包里有 QuickDoc.app")

            let rejectedRoot = root.appendingPathComponent("rejected", isDirectory: true)
            do {
                _ = try await SoftwareUpdatePipeline.prepare(
                    asset: GitHubReleaseAsset(name: "QuickDoc-9.9.9.zip", downloadURL: assetURL, digest: "sha256:" + String(repeating: "cd", count: 32)),
                    version: "9.9.9",
                    bundleIdentifier: "com.skyimplied.QuickDoc",
                    appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                    loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem",
                    rootURL: rejectedRoot,
                    fetcher: SoftwareUpdateTransfer(),
                    progress: { _, _ in },
                    onVerify: {}
                )
                expect(false, "校验值不符的包不能进入安装")
            } catch {
                expect(match(error, "digest"), "校验值不符时停止")
            }
            expect(!FileManager.default.fileExists(atPath: rejectedRoot.path), "被拒绝的下载目录会被清掉")

            let slow = try LoopbackServer(directory: archive.deletingLastPathComponent(), delay: 0.35)
            defer { slow.stop() }
            let cancelRoot = root.appendingPathComponent("cancel", isDirectory: true)
            let cancelTransfer = SoftwareUpdateTransfer()
            let cancelURL = URL(string: "http://127.0.0.1:\(slow.port)/package.zip")!
            let cancelTask = Task {
                try await SoftwareUpdatePipeline.prepare(
                    asset: GitHubReleaseAsset(name: "QuickDoc-9.9.9.zip", downloadURL: cancelURL, digest: digest),
                    version: "9.9.9",
                    bundleIdentifier: "com.skyimplied.QuickDoc",
                    appexBundleIdentifier: "com.skyimplied.QuickDoc.FinderSync",
                    loginItemBundleIdentifier: "com.skyimplied.QuickDoc.LoginItem",
                    rootURL: cancelRoot,
                    fetcher: cancelTransfer,
                    progress: { _, _ in cancelTransfer.cancel() },
                    onVerify: {}
                )
            }
            do {
                _ = try await cancelTask.value
                expect(false, "取消后不能得到待安装包")
            } catch {
                expect(match(error, "cancelled"), "取消下载会停在取消状态")
            }
            expect(!FileManager.default.fileExists(atPath: cancelRoot.path), "取消后不留下安装目录")

            let refused = SoftwareUpdateTransfer()
            do {
                try await refused.fetch(
                    request: URLRequest(url: URL(string: "http://127.0.0.1:1/package.zip")!),
                    destination: root.appendingPathComponent("refused.zip"),
                    progress: { _, _ in }
                )
                expect(false, "连不上的地址必须失败")
            } catch {
                expect(match(error, "network"), "连不上时返回网络失败")
            }
            SoftwareUpdateDownloadPolicy.allowLoopbackForTesting = false

            let installed = root.appendingPathComponent("Applications/QuickDoc.app")
            let replacement = root.appendingPathComponent("replacement/QuickDoc.app")
            try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: app, to: installed)
            try "old".write(to: installed.appendingPathComponent("Contents/generation.txt"), atomically: true, encoding: .utf8)
            try FileManager.default.createDirectory(at: replacement.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: app, to: replacement)
            try "new".write(to: replacement.appendingPathComponent("Contents/generation.txt"), atomically: true, encoding: .utf8)
            let marker = root.appendingPathComponent("marker.txt")
            let cleanup = root.appendingPathComponent("cleanup", isDirectory: true)
            let status = try runInstaller(target: installed, source: replacement, cleanup: cleanup, marker: marker, failAfterBackup: false)
            let generation = try String(contentsOf: installed.appendingPathComponent("Contents/generation.txt"), encoding: .utf8)
            let markerText = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
            let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path)) ?? []
            expect(status == 0 && generation == "new" && markerText == "9.9.9\n", "隔离目录里的替换会换上新版本并写下完成标记")
            expect(!leftovers.contains(where: { $0.hasPrefix(".QuickDoc.backup-") || $0.hasPrefix(".QuickDoc.update-") }), "成功后会清掉临时备份")

            try "old-again".write(to: installed.appendingPathComponent("Contents/generation.txt"), atomically: true, encoding: .utf8)
            let restoreCleanup = root.appendingPathComponent("cleanup-restore", isDirectory: true)
            let restoreStatus = try runInstaller(target: installed, source: replacement, cleanup: restoreCleanup, marker: root.appendingPathComponent("marker-restore.txt"), failAfterBackup: true)
            let restored = try String(contentsOf: installed.appendingPathComponent("Contents/generation.txt"), encoding: .utf8)
            expect(restoreStatus != 0 && restored == "old-again", "替换失败时恢复原来的应用")
        } catch {
            expect(false, "隔离测试没有跑完：\(error.localizedDescription)")
        }

        if !failures.isEmpty {
            fputs("\(failures.count) failed\n", stderr)
            exit(1)
        }
        print("PASS \(checks) software update checks")
    }
}
