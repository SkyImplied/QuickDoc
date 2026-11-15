import SwiftUI

struct PermissionWalkthroughCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback = PermissionWalkthroughPlayback()
    @State private var playbackGeneration = 0

    private let stageMinHeight: CGFloat = 300

    var body: some View {
        FillCardToWindowBottom { fills in
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                SystemSettingsWalkthrough(step: playback.step, reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil)
                    .frame(height: fills ? nil : stageMinHeight)
                    .frame(minHeight: stageMinHeight)
                    .padding(.horizontal, 16)

                navigator
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .top)
            .liquidGlassCard()
        }
        .onAppear {
            if !reduceMotion {
                playback.play()
            }
        }
        .onChange(of: reduceMotion) { shouldReduce in
            if shouldReduce {
                playback.pause()
            }
        }
        .task(id: playbackGeneration) {
            await playWalkthrough()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L("如何启用扩展"))
                    .font(.headline)
                Text(L("跟随真实的系统设置界面，找到 QuickDoc 并打开“文件提供程序”。"))
                    .font(.callout)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if reduceMotion {
                Label(L("静态预览"), systemImage: "figure.stand")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }

            if !reduceMotion {
                Button(action: togglePlayback) {
                    Label(playback.isPlaying ? L("暂停") : L("播放"), systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                }
                .controlSize(.small)
                .glassButtonStyle()
            }

            Button(action: replay) {
                Label(L("重新播放"), systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .glassButtonStyle()
        }
    }

    private var navigator: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("\(playback.step.number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(LF("步骤 %@ / %@", "\(playback.step.number)", "\(PermissionWalkthroughStep.allCases.count)"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.primary.opacity(0.62))
                    Text(L(playback.step.titleKey))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .contentTransition(.opacity)
                        .id(playback.step)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                navButton(L("上一步"), systemImage: "chevron.left", enabled: playback.canGoBackward, action: goBackward)

                HStack(spacing: 6) {
                    ForEach(PermissionWalkthroughStep.allCases) { item in
                        Button {
                            selectStep(item)
                        } label: {
                            Capsule()
                                .fill(item == playback.step ? Color.accentColor : Color.primary.opacity(0.18))
                                .frame(width: item == playback.step ? 22 : 8, height: 8)
                                .overlay {
                                    Capsule()
                                        .stroke(item == playback.step ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .frame(width: 22, height: 22)
                        .accessibilityLabel(L(item.instructionKey))
                        .accessibilityAddTraits(item == playback.step ? [.isSelected, .isButton] : [.isButton])
                    }
                }
                .animation(motion(duration: 0.3), value: playback.step)

                navButton(L("下一步"), systemImage: "chevron.right", enabled: playback.canGoForward, action: goForward)
            }
        }
    }

    private func navButton(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? Color.primary.opacity(0.85) : Color.primary.opacity(0.28))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(enabled ? 0.07 : 0.04), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(title)
        .accessibilityLabel(title)
    }

    private func selectStep(_ step: PermissionWalkthroughStep) {
        withAnimation(motion()) {
            playback.select(step)
        }
    }

    private func goForward() {
        withAnimation(motion()) {
            playback.goForward(userInitiated: true)
        }
    }

    private func goBackward() {
        withAnimation(motion()) {
            playback.goBackward()
        }
    }

    private func togglePlayback() {
        playback.togglePlayback()
    }

    private func replay() {
        withAnimation(motion()) {
            playback.replay(autoplay: !reduceMotion)
        }
        playbackGeneration += 1
    }

    private func motion(duration: Double = PermissionWalkthroughPlayback.transitionDuration) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration)
    }

    @MainActor
    private func playWalkthrough() async {
        if reduceMotion {
            return
        }

        while !Task.isCancelled {
            if !playback.isPlaying {
                do {
                    try await Task.sleep(nanoseconds: 120_000_000)
                } catch {
                    return
                }
                continue
            }

            let current = playback.step
            do {
                try await Task.sleep(nanoseconds: PermissionWalkthroughPlayback.dwellNanoseconds(for: current))
            } catch {
                return
            }

            guard !Task.isCancelled, playback.isPlaying, playback.step == current else {
                continue
            }

            withAnimation(motion()) {
                playback.advanceIfPlaying()
            }
        }
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
                        .frame(width: min(214, max(168, proxy.size.width * 0.30)))

                    Divider()

                    ExtensionSettingsPane(step: step, reduceMotion: reduceMotion, stageHeight: proxy.size.height)
                }

                if step == .toggle {
                    Color.black.opacity(colorScheme == .dark ? 0.48 : 0.28)
                        .transition(.opacity)

                    ExtensionSheetFocus(containerSize: proxy.size, reduceMotion: reduceMotion)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.97).combined(with: .opacity))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .background(SystemSettingsDemoPalette.paneBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SystemSettingsDemoPalette.border(for: colorScheme), lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: PermissionWalkthroughPlayback.transitionDuration), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("启用 QuickDoc 扩展的四步演示：进入登录项与扩展，找到 QuickDoc，点击信息按钮，然后打开文件提供程序开关。"))
    }
}

private struct SystemSettingsSidebar: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.32, blue: 0.34))
                Circle().fill(Color(red: 1, green: 0.75, blue: 0.05))
                Circle().fill(Color(red: 0.18, green: 0.78, blue: 0.35))
            }
            .frame(width: 54, height: 12)
            .padding(.top, 12)
            .padding(.leading, 14)

            Label(L("搜索"), systemImage: "magnifyingglass")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.primary.opacity(0.7))
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .background(
                    SystemSettingsDemoPalette.searchFieldBackground(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .padding(.horizontal, 12)

            VStack(spacing: 4) {
                SettingsSidebarRow(title: L("通用"), systemImage: "gearshape.fill", tint: .gray, isSelected: true)
                SettingsSidebarRow(title: L("隐私与安全性"), systemImage: "hand.raised.fill", tint: .blue)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint, in: RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ExtensionSettingsPane: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: PermissionWalkthroughStep
    let reduceMotion: Bool
    var stageHeight: CGFloat = 300

    private var rhythm: CGFloat {
        min(28, max(0, stageHeight - 300) * 0.18)
    }

    private var focusesList: Bool {
        step == .quickDoc || step == .details
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.regularMaterial, in: Capsule())

                Text(L("登录项与扩展"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .modifier(WalkthroughHighlight(isActive: step == .loginItems, cornerRadius: 8))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12 + rhythm * 0.3)
            .padding(.bottom, 8 + rhythm * 0.2)
            .walkthroughEmphasis(step == .loginItems, dimmedOpacity: 0.58)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("扩展"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text(L("扩展可在 Mac 和 App 中添加额外功能，部分扩展可能会在后台运行。"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.primary.opacity(0.68))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)

                ExtensionScopeSwitcher()
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    QuickDocExtensionRow(
                        rowIsFocused: step == .quickDoc,
                        infoIsFocused: step == .details,
                        reduceMotion: reduceMotion
                    )

                    Divider().padding(.leading, 58)

                    SystemServiceRow()
                        .walkthroughEmphasis(!focusesList, dimmedOpacity: 0.42)
                }
                .background(
                    SystemSettingsDemoPalette.groupBackground(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(SystemSettingsDemoPalette.border(for: colorScheme), lineWidth: 1)
                }
                .padding(.horizontal, 16)

                Text(L("点击信息按钮可以管理该应用安装的扩展。"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primary.opacity(0.62))
                    .padding(.horizontal, 24)
            }
            .walkthroughEmphasis(step != .loginItems, dimmedOpacity: 0.38)
            .padding(.bottom, 8 + rhythm)

            Spacer(minLength: 12)
        }
        .background(SystemSettingsDemoPalette.paneBackground(for: colorScheme))
    }
}

private struct ExtensionScopeSwitcher: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text(L("按 App"))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            Text(L("按类别"))
                .foregroundStyle(Color.primary.opacity(0.86))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .frame(height: 26)
        .background(SystemSettingsDemoPalette.segmentedControlBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
            : Color.white.opacity(0.92)
    }

    static func searchFieldBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.black.opacity(0.07)
    }

    static func segmentedControlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.07)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.10)
    }
}

private struct QuickDocExtensionRow: View {
    let rowIsFocused: Bool
    let infoIsFocused: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("QuickDoc")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(L("文件提供程序"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.68))
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary.opacity(0.72))
                .frame(width: 32, height: 32)
                .overlay {
                    if infoIsFocused {
                        PulseTarget(diameter: 36, reduceMotion: reduceMotion)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if infoIsFocused {
                        TargetCursor().offset(x: -18, y: 14)
                    }
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(rowIsFocused || infoIsFocused ? Color.accentColor.opacity(0.12) : Color.clear)
        .modifier(WalkthroughHighlight(isActive: rowIsFocused, cornerRadius: 10, showsFill: false))
        .padding(3)
        .overlay(alignment: .center) {
            if rowIsFocused {
                TargetCursor().offset(x: -52, y: 6)
            }
        }
    }
}

private struct SystemServiceRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.gray, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(L("系统服务"))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(L("标记、创建 PDF、转换图像"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.68))
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
    }
}

private struct ExtensionSheetFocus: View {
    let containerSize: CGSize
    let reduceMotion: Bool

    var body: some View {
        let widthCap = min(containerSize.width * 0.72, 520)
        let heightCap = max(196, containerSize.height - 24)
        let sheetWidth = min(widthCap, heightCap * 940 / 930)
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
                .shadow(color: .black.opacity(0.26), radius: 22, y: 10)

            PulseTarget(diameter: 52, reduceMotion: reduceMotion)
                .position(x: toggleX, y: toggleY)

            TargetCursor()
                .position(x: toggleX - 36, y: toggleY + 28)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
}

private struct PulseTarget: View {
    let diameter: CGFloat
    var reduceMotion = false
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.92), lineWidth: 2.5)
                .frame(width: diameter, height: diameter)

            if !reduceMotion {
                Circle()
                    .stroke(Color.accentColor.opacity(isPulsing ? 0 : 0.5), lineWidth: 2.5)
                    .frame(
                        width: isPulsing ? diameter * 1.55 : diameter,
                        height: isPulsing ? diameter * 1.55 : diameter
                    )
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.15).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

private struct TargetCursor: View {
    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(5)
            .background(Color.accentColor, in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.92), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
    }
}

private struct WalkthroughHighlight: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = 8
    var showsFill = true

    func body(content: Content) -> some View {
        content
            .background {
                if isActive, showsFill {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
    }
}

private extension View {
    func walkthroughEmphasis(_ isEmphasized: Bool, dimmedOpacity: Double = 0.46) -> some View {
        opacity(isEmphasized ? 1 : dimmedOpacity)
    }
}
