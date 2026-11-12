import AppKit
import SwiftUI

struct SoftwareUpdatePanel: View {
    let phase: SoftwareUpdatePanelPhase
    let onCancel: () -> Void
    let onInstall: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(status)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                NativeProgressBar(value: progressValue)
                    .frame(height: 10)

                HStack(alignment: .center, spacing: 12) {
                    if sizeText.isEmpty {
                        Spacer(minLength: 0)
                    } else {
                        Text(sizeText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                    }
                    actionButton
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 440)
    }

    private var icon: NSImage {
        let image = (NSApp.applicationIconImage.copy() as? NSImage) ?? NSImage()
        image.size = NSSize(width: 58, height: 58)
        return image
    }

    private var status: String {
        switch phase {
        case .downloading:
            return L("正在下载更新...")
        case .verifying:
            return L("正在校验更新包...")
        case .ready:
            return L("可以开始安装了")
        case let .failed(message):
            return message
        case .installing:
            return L("正在安装")
        }
    }

    private var progressValue: Double {
        switch phase {
        case let .downloading(received, expected):
            guard expected > 0 else { return -1 }
            return min(1, Double(received) / Double(expected))
        case .verifying:
            return -1
        case .ready, .installing:
            return 1
        case .failed:
            return 0
        }
    }

    private var sizeText: String {
        guard case let .downloading(received, expected) = phase, expected > 0 else {
            return ""
        }
        return SoftwareUpdateByteFormat.pair(received: received, expected: expected)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch phase {
        case .downloading:
            Button(L("取消"), action: onCancel)
                .controlSize(.large)
        case .ready:
            Button(L("安装并重启应用"), action: onInstall)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .failed:
            Button(L("重试"), action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .verifying, .installing:
            Button(L("取消"), action: {})
                .controlSize(.large)
                .disabled(true)
        }
    }
}

struct NativeProgressBar: NSViewRepresentable {
    var value: Double

    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .bar
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.isBezeled = false
        indicator.controlSize = .regular
        return indicator
    }

    func updateNSView(_ indicator: NSProgressIndicator, context: Context) {
        if value < 0 {
            indicator.isIndeterminate = true
            indicator.startAnimation(nil)
        } else {
            indicator.isIndeterminate = false
            indicator.stopAnimation(nil)
            indicator.doubleValue = min(1, max(0, value))
        }
    }
}

@MainActor
final class SoftwareUpdateWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var phase: SoftwareUpdatePanelPhase = .downloading(received: 0, expected: 0)
    private var onCancel: () -> Void = {}
    private var onInstall: () -> Void = {}
    private var onRetry: () -> Void = {}
    private var onUserClose: () -> Void = {}
    private var suppressClose = false

    func show(
        phase: SoftwareUpdatePanelPhase,
        onCancel: @escaping () -> Void,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onUserClose: @escaping () -> Void
    ) {
        self.phase = phase
        self.onCancel = onCancel
        self.onInstall = onInstall
        self.onRetry = onRetry
        self.onUserClose = onUserClose
        if window == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 120),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            panel.title = L("正在更新QuickDoc")
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            window = panel
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshLocalization),
                name: .quickDocLanguageDidChange,
                object: nil
            )
        }
        render()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func update(_ phase: SoftwareUpdatePanelPhase) {
        self.phase = phase
        render()
    }

    func orderFront() {
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        suppressClose = true
        window?.close()
        window = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if case .installing = phase {
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard !suppressClose else {
            suppressClose = false
            return
        }
        onUserClose()
    }

    @objc private func refreshLocalization() {
        window?.title = L("正在更新QuickDoc")
        render()
    }

    private func render() {
        guard let window else { return }
        window.title = L("正在更新QuickDoc")
        let root = SoftwareUpdatePanel(
            phase: phase,
            onCancel: { [weak self] in self?.onCancel() },
            onInstall: { [weak self] in self?.onInstall() },
            onRetry: { [weak self] in self?.onRetry() }
        )
        let host = NSHostingView(rootView: root)
        window.contentView = host
        let fit = host.fittingSize
        window.setContentSize(NSSize(width: 440, height: max(108, ceil(fit.height))))
    }
}
