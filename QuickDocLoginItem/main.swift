import AppKit
import Darwin

private let launchAtLoginURL = URL(string: "quickdoc://launch-at-login")!

let mainApplicationURL = Bundle.main.bundleURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

guard mainApplicationURL.pathExtension == "app" else {
    exit(EXIT_FAILURE)
}

let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false

let semaphore = DispatchSemaphore(value: 0)
var launchSucceeded = false

NSWorkspace.shared.open(
    [launchAtLoginURL],
    withApplicationAt: mainApplicationURL,
    configuration: configuration
) { _, error in
    launchSucceeded = error == nil
    semaphore.signal()
}

guard semaphore.wait(timeout: .now() + 10) == .success, launchSucceeded else {
    exit(EXIT_FAILURE)
}

exit(EXIT_SUCCESS)
