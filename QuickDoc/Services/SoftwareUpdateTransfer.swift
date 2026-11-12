import Cocoa
import CryptoKit
import Foundation

enum SoftwareUpdateByteFormat {
    static func pair(received: Int64, expected: Int64) -> String {
        "\(text(received)) / \(text(expected))"
    }

    static func text(_ bytes: Int64) -> String {
        let value = max(0, bytes)
        let locale = Locale(identifier: "en_US_POSIX")
        if value < 1_048_576 {
            let kilobytes = Double(value) / 1024
            return String(format: "%.0f KB", locale: locale, kilobytes)
        }
        let megabytes = Double(value) / 1_048_576
        return String(format: "%.1f MB", locale: locale, megabytes)
    }
}

enum SoftwareUpdateDownloadPolicy {
    /// The running app never sets this. Isolated tests enable it so the real
    /// transfer can use a loopback server instead of GitHub.
    static var allowLoopbackForTesting = false

    static func allows(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            return false
        }
        if allowLoopbackForTesting && scheme == "http" && (host == "127.0.0.1" || host == "localhost") {
            return true
        }
        guard scheme == "https" else { return false }
        return host == "github.com"
            || host == "objects.githubusercontent.com"
            || host == "release-assets.githubusercontent.com"
            || host == "github-releases.githubusercontent.com"
    }
}

protocol SoftwareUpdateFetching: AnyObject {
    func fetch(
        request: URLRequest,
        destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws
    func cancel()
}

final class SoftwareUpdateTransfer: NSObject, SoftwareUpdateFetching, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var destination: URL?
    private var progressHandler: (@Sendable (Int64, Int64) -> Void)?
    private var completion: ((Result<HTTPURLResponse, Error>) -> Void)?
    private var didResume = false
    private var savedFile = false

    func fetch(
        request: URLRequest,
        destination: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        guard let url = request.url, SoftwareUpdateDownloadPolicy.allows(url) else {
            throw SoftwareUpdateError.invalidDownloadURL
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            self.destination = destination
            self.progressHandler = progress
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60 * 30
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.downloadTask(with: request)
            self.task = task
            self.completion = { result in
                switch result {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
            lock.unlock()
            task.resume()
        }
    }

    func cancel() {
        lock.lock()
        task?.cancel()
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, SoftwareUpdateDownloadPolicy.allows(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 0
        lock.lock()
        let handler = progressHandler
        lock.unlock()
        handler?(totalBytesWritten, expected)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        let destination = destination
        lock.unlock()
        guard let destination else { return }
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            lock.lock()
            savedFile = true
            lock.unlock()
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            let code = (error as NSError).code
            if code == NSURLErrorCancelled {
                finish(.failure(SoftwareUpdateError.cancelled))
            } else {
                finish(.failure(SoftwareUpdateError.networkFailed))
            }
            return
        }
        lock.lock()
        let saved = savedFile
        lock.unlock()
        guard saved, let response = task.response as? HTTPURLResponse else {
            finish(.failure(SoftwareUpdateError.downloadFailed(-1)))
            return
        }
        guard (200..<300).contains(response.statusCode) else {
            finish(.failure(SoftwareUpdateError.downloadFailed(response.statusCode)))
            return
        }
        finish(.success(response))
    }

    private func finish(_ result: Result<HTTPURLResponse, Error>) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        let completion = self.completion
        let session = self.session
        self.completion = nil
        self.session = nil
        self.task = nil
        lock.unlock()
        session?.finishTasksAndInvalidate()
        completion?(result)
    }
}

enum SoftwareUpdateChecksum {
    static func verify(file: URL, digest: String) throws {
        let expected = digest.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard expected.hasPrefix("sha256:") else {
            throw SoftwareUpdateError.missingDigest
        }
        let hex = String(expected.dropFirst("sha256:".count))
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else {
            throw SoftwareUpdateError.missingDigest
        }
        let data = try Data(contentsOf: file)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == hex else {
            throw SoftwareUpdateError.digestMismatch
        }
    }
}

enum SoftwareUpdatePackageChecker {
    static func validate(
        appURL: URL,
        expectedVersion: String,
        bundleIdentifier: String,
        appexBundleIdentifier: String,
        loginItemBundleIdentifier: String
    ) async throws {
        try requireIdentity(
            appURL.appendingPathComponent("Contents/Info.plist"),
            identifier: bundleIdentifier,
            version: expectedVersion
        )
        try requireIdentity(
            appURL.appendingPathComponent("Contents/PlugIns/QuickDocFinderSync.appex/Contents/Info.plist"),
            identifier: appexBundleIdentifier,
            version: expectedVersion
        )
        try requireIdentity(
            appURL.appendingPathComponent("Contents/Library/LoginItems/QuickDocLoginItem.app/Contents/Info.plist"),
            identifier: loginItemBundleIdentifier,
            version: expectedVersion
        )

        let result = await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path])
        guard result.exitCode == 0 else {
            throw SoftwareUpdateError.invalidCodeSignature(result.error.isEmpty ? "codesign \(result.exitCode)" : result.error)
        }
    }

    private static func requireIdentity(_ plistURL: URL, identifier: String, version: String) throws {
        let data = try Data(contentsOf: plistURL)
        guard let payload = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              payload["CFBundleIdentifier"] as? String == identifier else {
            throw SoftwareUpdateError.invalidBundleIdentifier
        }
        let actual = payload["CFBundleShortVersionString"] as? String ?? ""
        guard actual == version else {
            throw SoftwareUpdateError.mismatchedBundleVersion(expected: version, actual: actual)
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) async -> (exitCode: Int32, error: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardError = errorPipe
            process.terminationHandler = { process in
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, error))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }
}

enum SoftwareUpdatePipeline {
    static func prepare(
        asset: GitHubReleaseAsset,
        version: String,
        bundleIdentifier: String,
        appexBundleIdentifier: String,
        loginItemBundleIdentifier: String,
        rootURL: URL,
        fetcher: SoftwareUpdateFetching,
        progress: @escaping @Sendable (Int64, Int64) -> Void,
        onVerify: @escaping @Sendable () -> Void
    ) async throws -> PreparedSoftwareUpdate {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
            guard SoftwareUpdateDownloadPolicy.allows(asset.downloadURL) else {
                throw SoftwareUpdateError.invalidDownloadURL
            }
            guard !asset.digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SoftwareUpdateError.missingDigest
            }

            let archiveURL = rootURL.appendingPathComponent(asset.name)
            var request = URLRequest(url: asset.downloadURL)
            request.setValue("QuickDoc", forHTTPHeaderField: "User-Agent")
            try await fetcher.fetch(request: request, destination: archiveURL, progress: progress)
            let byteCount = (try FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            try SoftwareUpdateChecksum.verify(file: archiveURL, digest: asset.digest)

            onVerify()
            let extractedURL = rootURL.appendingPathComponent("extracted", isDirectory: true)
            try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)
            let extract = await runDitto(archiveURL, extractedURL)
            guard extract == 0 else {
                throw SoftwareUpdateError.extractionFailed("ditto \(extract)")
            }
            let appURL = extractedURL.appendingPathComponent("QuickDoc.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                throw SoftwareUpdateError.missingAppBundle
            }
            try await SoftwareUpdatePackageChecker.validate(
                appURL: appURL,
                expectedVersion: version,
                bundleIdentifier: bundleIdentifier,
                appexBundleIdentifier: appexBundleIdentifier,
                loginItemBundleIdentifier: loginItemBundleIdentifier
            )
            return PreparedSoftwareUpdate(rootURL: rootURL, appURL: appURL, version: version, byteCount: byteCount)
        } catch {
            try? FileManager.default.removeItem(at: rootURL)
            throw error
        }
    }

    private static func runDitto(_ archive: URL, _ destination: URL) async -> Int32 {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", archive.path, destination.path]
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
    }
}

enum SoftwareUpdateInstaller {
    static func script() -> String {
        """
        #!/bin/sh
        set -u

        target_app="$1"
        source_app="$2"
        old_pid="$3"
        cleanup_root="$4"
        update_marker="$5"
        installed_version="$6"
        failure_title="$7"
        failure_message="$8"
        parent_dir="$(/usr/bin/dirname "$target_app")"
        incoming_app="$parent_dir/.QuickDoc.update-$$.app"
        backup_app="$parent_dir/.QuickDoc.backup-$$.app"
        lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        open_tool="${QUICKDOC_UPDATE_OPEN:-/usr/bin/open}"

        show_failure() {
          if [ -e "$backup_app" ] && [ ! -e "$target_app" ]; then
            /bin/mv "$backup_app" "$target_app" >/dev/null 2>&1 || true
          fi
          /bin/rm -rf "$incoming_app"
          if [ "${QUICKDOC_UPDATE_SKIP_UI:-}" != "1" ]; then
            /usr/bin/open -R "$source_app" >/dev/null 2>&1 || true
            /usr/bin/osascript -e "on run argv" -e "display alert (item 1 of argv) message (item 2 of argv)" -e "end run" - "$failure_title" "$failure_message" >/dev/null 2>&1 || true
          fi
          exit 1
        }

        case "$target_app" in
          */QuickDoc.app) ;;
          *) show_failure ;;
        esac
        if [ ! -d "$source_app" ]; then
          show_failure
        fi

        while /bin/kill -0 "$old_pid" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done

        # Stop only processes launched from the bundle being replaced.
        # This does not quit Finder and does not unregister the extension.
        /bin/ps -ax -o pid=,command= | while IFS= read -r line; do
          pid="${line%% *}"
          command=$(printf '%s\n' "$line" | /usr/bin/sed 's/^[[:space:]]*[0-9][0-9]*[[:space:]]*//')
          case "$command" in
            "$target_app"|"$target_app"/*)
              if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
                /bin/kill "$pid" >/dev/null 2>&1 || true
              fi
              ;;
          esac
        done

        /bin/rm -rf "$incoming_app" "$backup_app"
        /usr/bin/ditto "$source_app" "$incoming_app" || show_failure
        if [ -e "$target_app" ]; then
          /bin/mv "$target_app" "$backup_app" || show_failure
        fi
        if [ "${QUICKDOC_UPDATE_FAIL_AFTER_BACKUP:-}" = "1" ]; then
          show_failure
        fi
        if /bin/mv "$incoming_app" "$target_app"; then
          if [ "${QUICKDOC_UPDATE_SKIP_LSREGISTER:-}" != "1" ]; then
            "$lsregister" -f -R -trusted "$target_app" >/dev/null 2>&1 || true
          fi
          /bin/mkdir -p "$(/usr/bin/dirname "$update_marker")" >/dev/null 2>&1 || true
          /usr/bin/printf '%s\\n' "$installed_version" > "$update_marker" 2>/dev/null || true
          if "$open_tool" -n "$target_app"; then
            /bin/rm -rf "$backup_app" "$cleanup_root"
            exit 0
          fi
        fi
        show_failure
        """
    }
}
