import AppKit
import SwiftUI

struct FinderExperienceDemoCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationAnchor = Date()

    private let cycleDuration = 10.5

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                    let elapsed = reduceMotion ? 4.8 : cycleTime(at: context.date)

                    HStack(alignment: .top, spacing: 16) {
                        FinderContextMenuDemo(elapsed: elapsed)
                        MenuBarInteractionDemo(elapsed: elapsed)
                    }
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("使用场景演示")
                    .font(.headline)
                Text("自动演示 Finder 右键菜单与菜单栏入口；菜单内容会跟随当前设置。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Label(reduceMotion ? "静态预览" : "循环演示", systemImage: reduceMotion ? "figure.stand" : "play.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(reduceMotion ? Color.secondary : Color.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.045), in: Capsule())

            if !reduceMotion {
                Button {
                    animationAnchor = Date()
                } label: {
                    Label("重新演示", systemImage: "arrow.clockwise")
                }
                .glassButtonStyle()
            }
        }
    }

    private func cycleTime(at date: Date) -> Double {
        date.timeIntervalSince(animationAnchor).truncatingRemainder(dividingBy: cycleDuration)
    }
}

private struct FinderContextMenuDemo: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    let elapsed: Double

    private let contextMenuWidth: CGFloat = 146
    private let submenuWidth: CGFloat = 174

    var body: some View {
        DemoPanel(
            title: "Finder 右键菜单",
            subtitle: finderStatusText,
            systemImage: "cursorarrow.click.2",
            tint: .blue
        ) {
            GeometryReader { proxy in
                let layout = FinderDemoLayout(size: proxy.size)

                ZStack(alignment: .topLeading) {
                    FinderWindowBackdrop(showCreatedFile: elapsed >= 7.25)

                    if contextMenuIsVisible {
                        finderContextMenu
                            .frame(width: contextMenuWidth)
                            .offset(x: layout.contextMenuOrigin.x, y: layout.contextMenuOrigin.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                    }

                    if submenuIsVisible {
                        newFileSubmenu
                            .frame(width: submenuWidth)
                            .offset(x: layout.submenuOrigin.x, y: layout.submenuOrigin.y)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    if elapsed >= 7.25 && elapsed < 9.25 {
                        Label("已创建 \(createdFileName)", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .overlay {
                                Capsule().stroke(Color.green.opacity(0.26), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 74)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    DemoPointer(
                        position: cursorPosition(layout: layout),
                        isClicking: finderClickIsVisible
                    )
                }
                .animation(.easeInOut(duration: 0.16), value: contextMenuIsVisible)
                .animation(.easeInOut(duration: 0.16), value: submenuIsVisible)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Finder 空白处右键演示。打开 QuickDoc 新建文件菜单并创建文件。")
        }
    }

    private var contextMenuIsVisible: Bool {
        elapsed >= 1.45 && elapsed < 7.15
    }

    private var submenuIsVisible: Bool {
        elapsed >= 3.65 && elapsed < 7.15
    }

    private var finderClickIsVisible: Bool {
        (elapsed >= 1.12 && elapsed < 1.45) || (elapsed >= 6.55 && elapsed < 6.85)
    }

    private var finderStatusText: String {
        switch elapsed {
        case ..<1.15: return "移动到文件夹空白处"
        case ..<2.55: return "右键呼出 Finder 菜单"
        case ..<4.65: return "指向“新建文件”"
        case ..<7.15: return "选择要创建的文件类型"
        case ..<9.20: return "文件创建完成"
        default: return "准备再次演示"
        }
    }

    private var createdFileName: String {
        firstFileType?.title.replacingOccurrences(of: "新建 ", with: "") ?? "新建文件"
    }

    private var firstFileType: MenuPreviewItem? {
        model.menuPreviewItems.first
    }

    private var finderContextMenu: some View {
        DemoMenuSurface {
            DemoMenuRow(title: "新建文件夹", systemImage: "folder.badge.plus")
            DemoMenuSeparator()
            DemoMenuRow(title: "显示简介", systemImage: "info.circle")
            DemoMenuRow(title: "查看显示选项", systemImage: "slider.horizontal.3")
            DemoMenuSeparator()
            DemoMenuRow(
                title: "新建文件",
                resourceName: "新建文件icon",
                hasSubmenu: true,
                isHighlighted: elapsed >= 2.65 && elapsed < 7.15
            )

            if model.terminalDirectEnabled {
                DemoMenuRow(title: "在终端中打开", resourceName: "终端直达")
            }

            if model.pathCopyEnabled {
                DemoMenuRow(title: "复制当前路径", resourceName: "文件路径")
            }

            if model.quickActionsEnabled || model.permanentDeleteEnabled {
                DemoMenuRow(title: "快捷操作", resourceName: "快捷操作", hasSubmenu: true)
            }
        }
    }

    private var newFileSubmenu: some View {
        DemoMenuSurface {
            let items = Array(model.menuPreviewItems.prefix(6))

            if items.isEmpty {
                DemoMenuRow(title: "未启用新建文件类型", systemImage: "doc", isEnabled: false)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DemoMenuRow(
                        title: item.title,
                        resourceName: resourceName(for: item.id),
                        systemImage: "doc",
                        hasSubmenu: item.templateCount > 0,
                        isHighlighted: index == 0 && elapsed >= 5.15 && elapsed < 7.15
                    )
                }
            }
        }
    }

    private func resourceName(for id: String) -> String? {
        switch id {
        case "txt": return "txt"
        case "md": return "md"
        case "docx": return "word_icon"
        case "xlsx": return "excel"
        case "csv": return "CSV"
        case "pptx": return "PPT"
        case "json": return "json"
        case "blank": return "空白"
        case "py": return "python"
        case "html": return "html"
        case "sh": return "shell"
        case "rtf": return "rtf"
        default: return nil
        }
    }

    private func cursorPosition(layout: FinderDemoLayout) -> CGPoint {
        let start = CGPoint(x: layout.size.width * 0.80, y: layout.size.height * 0.77)
        let click = CGPoint(x: layout.contextMenuOrigin.x + 4, y: layout.contextMenuOrigin.y + 5)
        let newFile = CGPoint(x: layout.contextMenuOrigin.x + 112, y: layout.contextMenuOrigin.y + 92)
        let firstType = CGPoint(x: layout.submenuOrigin.x + 130, y: layout.submenuOrigin.y + 14)
        let finish = CGPoint(x: layout.size.width * 0.64, y: layout.size.height * 0.72)

        switch elapsed {
        case ..<1.15:
            return interpolate(from: start, to: click, progress: segmentProgress(elapsed, 0.0, 1.15))
        case ..<2.55:
            return click
        case ..<3.45:
            return interpolate(from: click, to: newFile, progress: segmentProgress(elapsed, 2.55, 3.45))
        case ..<4.80:
            return newFile
        case ..<5.65:
            return interpolate(from: newFile, to: firstType, progress: segmentProgress(elapsed, 4.80, 5.65))
        case ..<7.15:
            return firstType
        case ..<8.20:
            return interpolate(from: firstType, to: finish, progress: segmentProgress(elapsed, 7.15, 8.20))
        default:
            return finish
        }
    }
}

private struct FinderDemoLayout {
    let size: CGSize
    let contextMenuOrigin: CGPoint
    let submenuOrigin: CGPoint

    init(size: CGSize) {
        self.size = size
        let contextX = max(18, min(size.width * 0.16, size.width - 338))
        let contextY = max(64, size.height * 0.22)
        contextMenuOrigin = CGPoint(x: contextX, y: contextY)
        submenuOrigin = CGPoint(x: contextX + 150, y: contextY + 74)
    }
}

private struct FinderWindowBackdrop: View {
    let showCreatedFile: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color.blue.opacity(0.055),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    DemoTrafficLight(color: .red)
                    DemoTrafficLight(color: .yellow)
                    DemoTrafficLight(color: .green)
                    Spacer()
                    Text("文稿")
                        .font(.caption2.weight(.semibold))
                    Spacer()
                    Color.clear.frame(width: 43)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.ultraThinMaterial)

                Divider()

                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                    Divider().frame(height: 15)
                    Image(systemName: "square.grid.2x2")
                    Spacer()
                    Image(systemName: "magnifyingglass")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.primary.opacity(0.025))

                Divider()
                Spacer()
            }

            DemoDesktopItem(title: "项目资料", systemImage: "folder.fill", tint: .blue)
                .offset(x: 22, y: 86)
            DemoDesktopItem(title: "设计稿", systemImage: "folder.fill", tint: .blue)
                .offset(x: 22, y: 158)

            if showCreatedFile {
                DemoDesktopItem(title: "新建文件", systemImage: "doc.fill", tint: .white)
                    .offset(x: 22, y: 230)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: showCreatedFile)
    }
}

private struct MenuBarInteractionDemo: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    let elapsed: Double

    private let mainMenuWidth: CGFloat = 202
    private let submenuWidth: CGFloat = 170

    var body: some View {
        DemoPanel(
            title: "菜单栏快捷入口",
            subtitle: menuBarStatusText,
            systemImage: "menubar.rectangle",
            tint: .purple
        ) {
            GeometryReader { proxy in
                let layout = MenuBarDemoLayout(size: proxy.size, mainMenuWidth: mainMenuWidth, submenuWidth: submenuWidth)

                ZStack(alignment: .topLeading) {
                    MenuBarDesktopBackdrop(isStatusItemActive: statusMenuIsVisible)

                    if statusMenuIsVisible {
                        statusMenu
                            .frame(width: mainMenuWidth)
                            .offset(x: layout.mainMenuOrigin.x, y: layout.mainMenuOrigin.y)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
                    }

                    if otherFeaturesSubmenuIsVisible {
                        otherFeaturesSubmenu
                            .frame(width: submenuWidth)
                            .offset(x: layout.submenuOrigin.x, y: layout.submenuOrigin.y)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }

                    DemoPointer(
                        position: cursorPosition(layout: layout),
                        isClicking: elapsed >= 1.0 && elapsed < 1.34
                    )
                }
                .animation(.easeInOut(duration: 0.16), value: statusMenuIsVisible)
                .animation(.easeInOut(duration: 0.16), value: otherFeaturesSubmenuIsVisible)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("菜单栏 QuickDoc 图标演示。点击图标后显示软件快捷菜单。")
        }
    }

    private var statusMenuIsVisible: Bool {
        elapsed >= 1.28 && elapsed < 8.75
    }

    private var otherFeaturesSubmenuIsVisible: Bool {
        elapsed >= 4.35 && elapsed < 7.65
    }

    private var menuBarStatusText: String {
        switch elapsed {
        case ..<1.0: return "移动到 QuickDoc 菜单栏图标"
        case ..<2.70: return "点击打开快捷菜单"
        case ..<4.30: return "浏览软件设置入口"
        case ..<7.65: return "查看“其他功能”开关"
        case ..<8.75: return "菜单操作完成"
        default: return "准备再次演示"
        }
    }

    private var statusMenu: some View {
        DemoMenuSurface {
            DemoMenuRow(title: "打开设置", systemImage: "gearshape")
            DemoMenuSeparator()
            DemoMenuRow(title: "显示方式", systemImage: "macwindow", hasSubmenu: true)
            DemoMenuRow(title: "新建文件类型", systemImage: "doc.badge.plus", hasSubmenu: true)
            DemoMenuRow(
                title: "其他功能",
                systemImage: "bolt.fill",
                hasSubmenu: true,
                isHighlighted: elapsed >= 3.55 && elapsed < 7.65
            )
            DemoMenuRow(title: "开机自启动", systemImage: "power", state: model.launchAtLogin)
            DemoMenuRow(
                title: "静默启动",
                systemImage: "moon.fill",
                state: model.silentLaunchAtLogin,
                isEnabled: model.launchAtLogin
            )
            DemoMenuSeparator()
            DemoMenuRow(title: "重启访达", systemImage: "arrow.clockwise")
            DemoMenuRow(title: "打开扩展设置", systemImage: "puzzlepiece.extension")
            DemoMenuSeparator()
            DemoMenuRow(title: "退出 QuickDoc", systemImage: "power.circle")
        }
    }

    private var otherFeaturesSubmenu: some View {
        DemoMenuSurface {
            DemoMenuRow(title: "终端直达", systemImage: "terminal", state: model.terminalDirectEnabled)
            DemoMenuRow(
                title: "路径复制",
                systemImage: "doc.on.doc",
                state: model.pathCopyEnabled,
                isHighlighted: elapsed >= 5.45 && elapsed < 7.15
            )
            DemoMenuRow(title: "快捷操作", systemImage: "wrench.and.screwdriver", state: model.quickActionsEnabled)
            DemoMenuRow(title: "展开快捷操作", systemImage: "list.bullet", state: model.quickActionsExpanded)
        }
    }

    private func cursorPosition(layout: MenuBarDemoLayout) -> CGPoint {
        let start = CGPoint(x: layout.size.width * 0.38, y: layout.size.height * 0.68)
        let statusItem = CGPoint(x: layout.size.width - 47, y: 15)
        let otherFeatures = CGPoint(x: layout.mainMenuOrigin.x + 154, y: layout.mainMenuOrigin.y + 91)
        let featureToggle = CGPoint(x: layout.submenuOrigin.x + 125, y: layout.submenuOrigin.y + 37)
        let finish = CGPoint(x: layout.size.width * 0.58, y: layout.size.height * 0.72)

        switch elapsed {
        case ..<1.0:
            return interpolate(from: start, to: statusItem, progress: segmentProgress(elapsed, 0.0, 1.0))
        case ..<2.65:
            return statusItem
        case ..<3.75:
            return interpolate(from: statusItem, to: otherFeatures, progress: segmentProgress(elapsed, 2.65, 3.75))
        case ..<4.75:
            return otherFeatures
        case ..<5.65:
            return interpolate(from: otherFeatures, to: featureToggle, progress: segmentProgress(elapsed, 4.75, 5.65))
        case ..<7.65:
            return featureToggle
        case ..<8.80:
            return interpolate(from: featureToggle, to: finish, progress: segmentProgress(elapsed, 7.65, 8.80))
        default:
            return finish
        }
    }
}

private struct MenuBarDemoLayout {
    let size: CGSize
    let mainMenuOrigin: CGPoint
    let submenuOrigin: CGPoint

    init(size: CGSize, mainMenuWidth: CGFloat, submenuWidth: CGFloat) {
        self.size = size
        let mainX = max(12, size.width - mainMenuWidth - 10)
        mainMenuOrigin = CGPoint(x: mainX, y: 29)
        submenuOrigin = CGPoint(x: max(10, mainX - submenuWidth - 4), y: 86)
    }
}

private struct MenuBarDesktopBackdrop: View {
    let isStatusItemActive: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.20), Color.blue.opacity(0.09), Color.purple.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 2)
                .offset(x: -50, y: 110)

            HStack(spacing: 9) {
                Image(systemName: "apple.logo")
                    .font(.caption.weight(.semibold))
                Text("Finder").fontWeight(.semibold)
                Text("文件")
                Text("编辑")
                Text("显示")
                Spacer(minLength: 5)
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
                Text("10:28")
                DemoResourceIcon(resourceName: "菜单栏", fallbackSystemImage: "doc.text", size: 14)
                    .padding(.horizontal, 5)
                    .frame(height: 22)
                    .background(isStatusItemActive ? Color.primary.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .font(.system(size: 9.5))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 8) {
                Text("菜单栏常驻")
                    .font(.caption.weight(.semibold))
                Text("无需打开主窗口，也能快速管理 QuickDoc。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 180, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
            .offset(x: 18, y: 232)
        }
    }
}

private struct DemoPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }

            content
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .background(Color.primary.opacity(0.018))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.022), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.075), lineWidth: 1)
        }
    }
}

private struct DemoMenuSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}

private struct DemoMenuRow: View {
    let title: String
    var resourceName: String?
    var systemImage: String?
    var state: Bool?
    var hasSubmenu = false
    var isEnabled = true
    var isHighlighted = false

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if let state {
                    if state {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                            .frame(width: 12)
                    } else {
                        Color.clear
                            .frame(width: 12, height: 12)
                    }
                } else {
                    DemoResourceIcon(
                        resourceName: resourceName,
                        fallbackSystemImage: systemImage ?? "circle",
                        size: 12
                    )
                    .frame(width: 12)
                }
            }

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            if hasSubmenu {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(rowForegroundStyle)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
        .background(isHighlighted ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .padding(.horizontal, 4)
    }

    private var rowForegroundStyle: Color {
        if isHighlighted { return .white }
        return isEnabled ? .primary : Color.secondary.opacity(0.55)
    }
}

private struct DemoMenuSeparator: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
    }
}

private struct DemoPointer: View {
    let position: CGPoint
    let isClicking: Bool

    var body: some View {
        ZStack {
            if isClicking {
                Circle()
                    .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                    .frame(width: 28, height: 28)
                    .transition(.scale.combined(with: .opacity))
            }

            ZStack {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(Color.white)
                    .offset(x: 1, y: 1)
                Image(systemName: "cursorarrow")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.black)
            }
            .offset(x: 7, y: 8)
            .shadow(color: .black.opacity(0.22), radius: 2, x: 1, y: 1)
        }
        .position(position)
        .animation(.easeInOut(duration: 0.12), value: isClicking)
        .allowsHitTesting(false)
    }
}

private struct DemoResourceIcon: View {
    let resourceName: String?
    let fallbackSystemImage: String
    let size: CGFloat

    var body: some View {
        if let resourceName,
           let image = Bundle.main.image(forResource: resourceName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: size * 0.82, weight: .medium))
        }
    }
}

private struct DemoDesktopItem: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            Text(title)
                .font(.system(size: 8.5))
                .lineLimit(1)
                .frame(width: 56)
        }
    }
}

private struct DemoTrafficLight: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.88))
            .frame(width: 8, height: 8)
    }
}

private func segmentProgress(_ value: Double, _ start: Double, _ end: Double) -> Double {
    guard end > start else { return 1 }
    let progress = min(max((value - start) / (end - start), 0), 1)
    return progress * progress * (3 - 2 * progress)
}

private func interpolate(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
    CGPoint(
        x: start.x + (end.x - start.x) * progress,
        y: start.y + (end.y - start.y) * progress
    )
}
