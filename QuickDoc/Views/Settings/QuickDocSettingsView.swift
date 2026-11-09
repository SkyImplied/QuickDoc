import SwiftUI

enum QuickDocWindowMetrics {
    static let defaultContentSize = NSSize(width: 960, height: 720)
    static let minimumContentSize = NSSize(width: 880, height: 660)
}

struct QuickDocSettingsView: View {
    @ObservedObject private var model: QuickDocSettingsModel
    @State private var selection: SettingsPage? = .general
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    init(model: QuickDocSettingsModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            sidebarToggle
        }
        .background {
            SidebarTrackingSeparatorRemover()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if #available(macOS 26.0, *) {
                SidebarShortcutMonitor(action: toggleSidebar)
            }
        }
        .environmentObject(model)
    }

    private var sidebar: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(nsImage: QuickDocIcon.applicationLogo())
                    .resizable()
                    .frame(width: 74, height: 74)
                    .shadow(radius: 8, y: 4)

                Text("QuickDoc")
                    .font(.title2.weight(.bold))

                Text("版本 \(model.appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 12)

            List(selection: $selection) {
                ForEach(SettingsPage.allCases) { page in
                    Label(page.title, systemImage: page.systemImage)
                        .font(.body.weight(.medium))
                        .tag(page)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .navigationSplitViewColumnWidth(min: 208, ideal: 228, max: 260)
        .accessibilityLabel("设置导航")
    }

    private var detail: some View {
        ScrollView {
            selectedPage
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: 1020, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollContentBackground(.hidden)
        .background(GlassBackground())
    }

    @ToolbarContentBuilder
    private var sidebarToggle: some ToolbarContent {
        if #available(macOS 26.0, *) {
            DefaultToolbarItem(kind: .sidebarToggle, placement: .navigation)
        } else {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Label(sidebarShown ? "隐藏侧边栏" : "显示侧边栏", systemImage: "sidebar.leading")
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .help(sidebarShown ? "隐藏侧边栏" : "显示侧边栏")
            }
        }
    }

    private var sidebarShown: Bool {
        columnVisibility != .detailOnly
    }

    private func toggleSidebar() {
        columnVisibility = sidebarShown ? .detailOnly : .all
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsPage()
        case .efficiencyTools:
            EfficiencyToolsPage()
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

private struct SidebarTrackingSeparatorRemover: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SeparatorCleanupView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? SeparatorCleanupView)?.removeTrackingSeparator()
    }
}

private final class SeparatorCleanupView: NSView {
    private var removing = false
    private var observer: CFRunLoopObserver?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer {
            CFRunLoopObserverInvalidate(observer)
            self.observer = nil
        }
        if window != nil {
            let observer = CFRunLoopObserverCreateWithHandler(
                nil,
                CFRunLoopActivity.beforeWaiting.rawValue,
                true,
                0
            ) { [weak self] _, _ in
                self?.removeTrackingSeparator()
            }
            self.observer = observer
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
        removeTrackingSeparator()
    }

    deinit {
        if let observer {
            CFRunLoopObserverInvalidate(observer)
        }
    }

    override func layout() {
        super.layout()
        removeTrackingSeparator()
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        removeTrackingSeparator()
    }

    func removeTrackingSeparator() {
        guard let toolbar = window?.toolbar, !removing else { return }
        let stray = toolbar.items.filter { item in
            let identifier = item.itemIdentifier.rawValue
            if identifier.contains("toggleSidebar") || identifier.contains("Flexible") || identifier.contains("splitViewSeparator") {
                return false
            }
            guard let view = item.value(forKey: "view") as? NSView else { return false }
            return view.bounds.width > 0 && view.bounds.width < 20
        }
        removing = true
        defer { removing = false }
        if #available(macOS 15.0, *), !stray.isEmpty {
            for item in stray {
                toolbar.removeItem(identifier: item.itemIdentifier)
            }
        }
        guard let content = window?.contentView else { return }
        var root = content
        while let parent = root.superview { root = parent }
        hideNarrowGlass(in: root)
    }

    private func hideNarrowGlass(in view: NSView) {
        let name = String(describing: type(of: view))
        if name.contains("Glass"), view.bounds.width > 2, view.bounds.width < 24, view.bounds.height > 20 {
            view.isHidden = true
        }
        for subview in view.subviews {
            hideNarrowGlass(in: subview)
        }
    }
}

private struct SidebarShortcutMonitor: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> SidebarShortcutMonitorView {
        let view = SidebarShortcutMonitorView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: SidebarShortcutMonitorView, context: Context) {
        nsView.action = action
    }
}

private final class SidebarShortcutMonitorView: NSView {
    var action: () -> Void = {}
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == [.command, .control],
                  event.charactersIgnoringModifiers?.lowercased() == "s" else {
                return event
            }
            self?.action()
            return nil
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
