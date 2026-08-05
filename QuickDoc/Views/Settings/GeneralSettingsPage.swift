import SwiftUI

struct GeneralSettingsPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "通用设置", subtitle: "管理 QuickDoc 的启动行为与基础偏好。")

            StartupSettingsCard()

            DisplayModeSettingsCard()
            AppearanceSettingsCard()
            SoftwareUpdateSettingsCard()
            LanguageSettingsCard()
        }
    }
}

private struct StartupSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    private let columns = [
        GridItem(.flexible(minimum: 280), spacing: 12),
        GridItem(.flexible(minimum: 280), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "power")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("启动与登录")
                            .font(.headline)
                        Text("设置 QuickDoc 登录 macOS 后是否自动运行，以及启动时是否显示主界面。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.launchAtLogin ? Color.green : Color.secondary.opacity(0.55))
                            .frame(width: 7, height: 7)
                        Text(startupStatus)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.045), in: Capsule())
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    StartupOptionCard(
                        title: "开机自启动",
                        subtitle: "登录 macOS 后自动运行 QuickDoc。",
                        systemImage: "bolt.fill",
                        tint: .blue,
                        isOn: $model.launchAtLogin
                    )

                    StartupOptionCard(
                        title: "静默启动",
                        subtitle: "在后台运行，不自动弹出软件主界面。",
                        systemImage: "moon.stars.fill",
                        tint: .purple,
                        dependencyText: "需先开启开机自启动",
                        isOn: $model.silentLaunchAtLogin,
                        isEnabled: model.launchAtLogin
                    )
                }
            }
        }
    }

    private var startupStatus: String {
        guard model.launchAtLogin else { return "手动启动" }
        return model.silentLaunchAtLogin ? "登录后后台启动" : "登录后自动启动"
    }
}

private struct StartupOptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var dependencyText: String?
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    isEnabled ? tint.opacity(0.11) : Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)

                    if !isEnabled, let dependencyText {
                        Text(dependencyText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.055), in: Capsule())
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isEnabled)
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            isOn && isEnabled ? tint.opacity(0.065) : Color.primary.opacity(0.022),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isOn && isEnabled ? tint.opacity(0.26) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        }
        .opacity(isEnabled ? 1 : 0.64)
    }
}

struct DisplayModeSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    private let columns = [
        GridItem(.flexible(minimum: 280), spacing: 12),
        GridItem(.flexible(minimum: 280), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 42, height: 42)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("显示方式")
                            .font(.headline)
                        Text("选择 QuickDoc 在菜单栏与 Dock 中的入口；切换后会立即生效。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text("当前：\(model.displayMode.title)")
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.045), in: Capsule())
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(QuickDocDisplayMode.allCases) { mode in
                        DisplayModeOptionCard(
                            mode: mode,
                            isSelected: model.displayMode == mode
                        ) {
                            model.requestDisplayModeChange(mode)
                        }
                    }
                }
            }
        }
    }
}

private struct DisplayModeOptionCard: View {
    let mode: QuickDocDisplayMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                DisplayModeMiniature(mode: mode, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(mode.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if mode == .menuBarOnly {
                            Text("推荐")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.11), in: Capsule())
                        }
                    }

                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.42))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.085)
                    : Color.primary.opacity(isHovered ? 0.045 : 0.022),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.42) : Color.primary.opacity(isHovered ? 0.14 : 0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("显示方式：\(mode.title)")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityHint(mode.subtitle)
    }
}

private struct DisplayModeMiniature: View {
    let mode: QuickDocDisplayMode
    let isSelected: Bool

    private var activeColor: Color {
        isSelected ? .accentColor : .secondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045))

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
                .frame(width: 38, height: 28)

            if mode.showsStatusItem {
                HStack(spacing: 2) {
                    Spacer()
                    Circle()
                        .fill(activeColor)
                        .frame(width: 3.5, height: 3.5)
                    Circle()
                        .fill(activeColor.opacity(0.55))
                        .frame(width: 3.5, height: 3.5)
                }
                .padding(.horizontal, 4)
                .frame(width: 38, height: 7)
                .background(activeColor.opacity(0.16))
                .offset(y: -10.5)
            }

            if mode.activationPolicy == .regular {
                HStack(spacing: 2.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(activeColor)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(activeColor.opacity(0.15), in: Capsule())
                .offset(y: 15)
            }

            if mode == .hiddenBoth {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}
