import SwiftUI

struct PermissionWalkthroughCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: PermissionWalkthroughStep = .loginItems
    @State private var playbackID = 0

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                header
                SystemSettingsWalkthrough(step: step, reduceMotion: reduceMotion)
                playbackProgress
            }
        }
        .task(id: playbackID) {
            await playWalkthrough()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Label("如何启用扩展", systemImage: "play.rectangle")
                    .font(.headline)
                Text("跟随真实的系统设置界面，找到 QuickDoc 并打开“文件提供程序”。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                playbackID += 1
            } label: {
                Label("重新播放", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .glassButtonStyle()
        }
    }

    private var playbackProgress: some View {
        HStack(spacing: 10) {
            ForEach(PermissionWalkthroughStep.allCases) { item in
                Capsule()
                    .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: item == step ? 24 : 7, height: 7)
            }

            Text(step.instruction)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .id(step)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: step)
    }

    @MainActor
    private func playWalkthrough() async {
        step = .loginItems

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 2_100_000_000)
            } catch {
                return
            }

            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) {
                step = step.next
            }
        }
    }
}

private enum PermissionWalkthroughStep: Int, CaseIterable, Identifiable {
    case loginItems
    case quickDoc
    case details
    case toggle

    var id: Int { rawValue }

    var instruction: String {
        switch self {
        case .loginItems:
            return "1. 进入“登录项与扩展”"
        case .quickDoc:
            return "2. 找到 QuickDoc"
        case .details:
            return "3. 点击右侧的信息按钮"
        case .toggle:
            return "4. 打开“文件提供程序”开关"
        }
    }

    var next: PermissionWalkthroughStep {
        let nextIndex = (rawValue + 1) % Self.allCases.count
        return Self(rawValue: nextIndex) ?? .loginItems
    }
}

private struct SystemSettingsWalkthrough: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: PermissionWalkthroughStep
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HStack(spacing: 0) {
                    SystemSettingsSidebar()
                        .frame(width: min(232, proxy.size.width * 0.31))

                    Divider()

                    ExtensionSettingsPane(step: step)
                }

                if step == .toggle {
                    Color.black.opacity(0.24)
                        .transition(.opacity)

                    ExtensionSheetFocus(containerSize: proxy.size)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(height: 470)
        .background(SystemSettingsDemoPalette.paneBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SystemSettingsDemoPalette.border(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("启用 QuickDoc 扩展的四步演示：进入登录项与扩展，找到 QuickDoc，点击信息按钮，然后打开文件提供程序开关。")
    }
}

private struct SystemSettingsSidebar: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Circle().fill(Color(red: 1, green: 0.32, blue: 0.34))
                Circle().fill(Color(red: 1, green: 0.75, blue: 0.05))
                Circle().fill(Color(red: 0.18, green: 0.78, blue: 0.35))
            }
            .frame(width: 68, height: 14)
            .padding(.top, 16)
            .padding(.leading, 15)

            Label("搜索", systemImage: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .background(
                    SystemSettingsDemoPalette.searchFieldBackground(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .padding(.horizontal, 14)

            VStack(spacing: 5) {
                SettingsSidebarRow(title: "通用", systemImage: "gearshape.fill", tint: .gray, isSelected: true)
                SettingsSidebarRow(title: "隐私与安全性", systemImage: "hand.raised.fill", tint: .blue)
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .background(SystemSettingsDemoPalette.sidebarBackground(for: colorScheme))
    }
}

private struct SettingsSidebarRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isSelected = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 23, height: 23)
                .background(tint, in: RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(.system(size: 13.5, weight: .medium))
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExtensionSettingsPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: PermissionWalkthroughStep

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 13) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(.regularMaterial, in: Capsule())

                Text("登录项与扩展")
                    .font(.system(size: 22, weight: .bold))
                    .overlay {
                        if step == .loginItems {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                                .padding(-7)
                                .transition(.opacity)
                        }
                    }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 3) {
                Text("扩展")
                    .font(.system(size: 18, weight: .bold))

                Text("扩展可在 Mac 和 App 中添加额外功能，部分扩展可能会在后台运行。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ExtensionScopeSwitcher()
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                QuickDocExtensionRow(
                    rowIsFocused: step == .quickDoc,
                    infoIsFocused: step == .details
                )

                Divider().padding(.leading, 60)

                SystemServiceRow()
            }
            .background(
                SystemSettingsDemoPalette.groupBackground(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SystemSettingsDemoPalette.border(for: colorScheme), lineWidth: 1)
            }
            .padding(.horizontal, 20)

            Text("点击信息按钮可以管理该应用安装的扩展。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 10)

            Spacer()
        }
        .background(SystemSettingsDemoPalette.paneBackground(for: colorScheme))
    }
}

private struct ExtensionScopeSwitcher: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text("按 App")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            Text("按类别")
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .font(.system(size: 14, weight: .semibold))
        .frame(height: 34)
        .background(SystemSettingsDemoPalette.segmentedControlBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum SystemSettingsDemoPalette {
    static func paneBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.105, green: 0.12, blue: 0.16)
            : Color(red: 0.965, green: 0.965, blue: 0.975)
    }

    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.19, blue: 0.23)
            : Color(red: 0.90, green: 0.93, blue: 0.95)
    }

    static func groupBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.145, green: 0.16, blue: 0.205)
            : Color.white.opacity(0.84)
    }

    static func searchFieldBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.075)
    }

    static func segmentedControlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.075)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.10)
    }
}

private struct QuickDocExtensionRow: View {
    let rowIsFocused: Bool
    let infoIsFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("QuickDoc")
                    .font(.system(size: 15, weight: .medium))
                Text("文件提供程序")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .overlay {
                    if infoIsFocused {
                        PulseTarget(diameter: 37)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if infoIsFocused {
                        TargetCursor().offset(x: -19, y: 15)
                    }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background(rowIsFocused ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay {
            if rowIsFocused {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .padding(3)
            }
        }
        .overlay(alignment: .center) {
            if rowIsFocused {
                TargetCursor().offset(x: -55, y: 6)
            }
        }
    }
}

private struct SystemServiceRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.gray, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text("系统服务")
                    .font(.system(size: 15, weight: .medium))
                Text("标记、创建 PDF、转换图像")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
    }
}

private struct ExtensionSheetFocus: View {
    let containerSize: CGSize

    var body: some View {
        let sheetWidth = min(containerSize.width * 0.54, 470)
        let sheetHeight = sheetWidth * 930 / 940
        let originX = (containerSize.width - sheetWidth) / 2
        let originY = (containerSize.height - sheetHeight) / 2
        let toggleX = originX + sheetWidth * 842 / 940
        let toggleY = originY + sheetHeight * 201 / 930

        ZStack {
            Image("PermissionExtensionSheet")
                .resizable()
                .interpolation(.high)
                .aspectRatio(940 / 930, contentMode: .fit)
                .frame(width: sheetWidth)
                .shadow(color: .black.opacity(0.28), radius: 24, y: 12)

            PulseTarget(diameter: 54)
                .position(x: toggleX, y: toggleY)

            TargetCursor()
                .position(x: toggleX - 38, y: toggleY + 30)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
}

private struct PulseTarget: View {
    let diameter: CGFloat
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.8), lineWidth: 3)
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(Color.accentColor.opacity(isPulsing ? 0 : 0.55), lineWidth: 3)
                .frame(
                    width: isPulsing ? diameter * 1.65 : diameter,
                    height: isPulsing ? diameter * 1.65 : diameter
                )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct TargetCursor: View {
    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(6)
            .background(Color.accentColor, in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
    }
}
