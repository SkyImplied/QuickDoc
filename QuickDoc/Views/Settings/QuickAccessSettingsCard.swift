import SwiftUI

struct EfficiencyToolsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: "效率工具",
                subtitle: "配置 Finder 右键菜单中的效率功能与文件操作。"
            )
            QuickAccessSettingsCard()
        }
    }
}

struct QuickAccessSettingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TerminalDirectSettingsCard()
            PathCopySettingsCard()
            QuickActionsSettingsCard()
        }
    }
}

struct TerminalDirectSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                EfficiencySectionHeader(
                    title: "终端直达",
                    subtitle: "从 Finder 右键菜单直接在指定终端中打开当前位置。",
                    systemImage: "command",
                    tint: .blue,
                    isEnabled: model.terminalDirectEnabled
                )

                EfficiencyFeatureToggleCard(
                    title: "显示“在终端中打开”",
                    subtitle: "启用后直接显示在 Finder 右键一级菜单。",
                    systemImage: "terminal.fill",
                    tint: .blue,
                    isOn: $model.terminalDirectEnabled
                )

                TerminalApplicationPicker()
            }
        }
    }
}

struct PathCopySettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                EfficiencySectionHeader(
                    title: "路径复制",
                    subtitle: "快速复制当前文件夹或所选项目的完整路径。",
                    systemImage: "doc.on.doc",
                    tint: .cyan,
                    isEnabled: model.pathCopyEnabled
                )

                EfficiencyFeatureToggleCard(
                    title: "显示“复制当前路径”",
                    subtitle: "启用后直接显示在 Finder 右键一级菜单。",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: .cyan,
                    isOn: $model.pathCopyEnabled
                )

                HStack(spacing: 12) {
                    PathCopyBehaviorCard(
                        title: "点击文件夹空白处",
                        result: "复制当前文件夹路径",
                        systemImage: "folder"
                    )
                    PathCopyBehaviorCard(
                        title: "选中文件或文件夹",
                        result: "复制所选项目路径",
                        systemImage: "doc.on.doc"
                    )
                }
            }
        }
    }
}

struct QuickActionsSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    private let actionColumns = [
        GridItem(.flexible(minimum: 170), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12),
        GridItem(.flexible(minimum: 170), spacing: 12)
    ]

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                EfficiencySectionHeader(
                    title: "文件操作",
                    subtitle: "管理 Finder 右键菜单中的文件传输与删除操作。",
                    systemImage: "wrench.and.screwdriver",
                    tint: .indigo,
                    statusText: enabledActionCount == 0 ? "未启用" : "\(enabledActionCount) 项已启用",
                    statusColor: enabledActionCount == 0 ? .secondary : .green
                )

                HStack(spacing: 12) {
                    EfficiencyFeatureToggleCard(
                        title: "拷贝、粘贴与剪切",
                        subtitle: "启用 QuickDoc 自有的文件传输操作。",
                        systemImage: "doc.on.doc",
                        tint: .indigo,
                        isOn: $model.quickActionsEnabled
                    )

                    EfficiencyFeatureToggleCard(
                        title: "彻底删除",
                        subtitle: "永久删除所选项目，执行前会再次确认。",
                        systemImage: "trash.slash.fill",
                        tint: .red,
                        isOn: $model.permanentDeleteEnabled
                    )
                }

                QuickActionsCompatibilityNotice()

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    SettingsSubsectionHeader(
                        title: "常用操作",
                        subtitle: "选择启用后要显示的具体操作。"
                    )

                    LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 12) {
                        QuickActionToggleCard(
                            title: "拷贝",
                            iconName: "复制",
                            fallbackSystemImage: "doc.on.doc",
                            isOn: $model.copyActionEnabled,
                            isEnabled: model.quickActionsEnabled
                        )
                        QuickActionToggleCard(
                            title: "粘贴",
                            iconName: "粘贴",
                            fallbackSystemImage: "clipboard",
                            isOn: $model.pasteActionEnabled,
                            isEnabled: model.quickActionsEnabled
                        )
                        QuickActionToggleCard(
                            title: "剪切",
                            iconName: "剪切",
                            fallbackSystemImage: "scissors",
                            isOn: $model.cutActionEnabled,
                            isEnabled: model.quickActionsEnabled
                        )
                    }
                }

                Divider()

                menuPlacementSection
            }
        }
    }

    private var enabledActionCount: Int {
        var count = 0
        if model.quickActionsEnabled {
            count += model.copyActionEnabled ? 1 : 0
            count += model.pasteActionEnabled ? 1 : 0
            count += model.cutActionEnabled ? 1 : 0
        }
        count += model.permanentDeleteEnabled ? 1 : 0
        return count
    }

    private var hasEnabledOperations: Bool {
        model.quickActionsEnabled || model.permanentDeleteEnabled
    }

    private var menuPlacementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSubsectionHeader(
                title: "菜单显示位置",
                subtitle: hasEnabledOperations ? "选择操作直接展开，或统一收进子菜单。" : "启用任一文件操作后即可设置显示位置。"
            )

            HStack(spacing: 12) {
                MenuPlacementOptionCard(
                    title: "收起显示",
                    subtitle: "归入“快捷操作”子菜单",
                    systemImage: "rectangle.stack",
                    isSelected: !model.quickActionsExpanded,
                    isEnabled: hasEnabledOperations
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.quickActionsExpanded = false
                    }
                }

                MenuPlacementOptionCard(
                    title: "一级菜单",
                    subtitle: "直接显示在 Finder 右键菜单",
                    systemImage: "list.bullet",
                    isSelected: model.quickActionsExpanded,
                    isEnabled: hasEnabledOperations
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        model.quickActionsExpanded = true
                    }
                }
            }
        }
    }
}

private struct QuickActionsCompatibilityNotice: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text("QuickDoc 的拷贝、粘贴和剪切需配套使用，与 Finder 系统菜单互不衔接。")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(warningColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(colorScheme == .dark ? 0.10 : 0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.yellow.opacity(colorScheme == .dark ? 0.22 : 0.30), lineWidth: 1)
        }
    }

    private var warningColor: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.79, blue: 0.20)
            : Color(red: 0.66, green: 0.39, blue: 0.00)
    }
}

private struct EfficiencySectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var statusText: String?
    var statusColor: Color = .green

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isEnabled: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        statusText = isEnabled ? "已启用" : "未启用"
        statusColor = isEnabled ? .green : .secondary
    }

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        statusText: String,
        statusColor: Color
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.statusText = statusText
        self.statusColor = statusColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let statusText {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusText)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.045), in: Capsule())
            }
        }
    }
}

private struct EfficiencyFeatureToggleCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.callout.weight(.semibold))
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
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(
            isOn ? tint.opacity(0.065) : Color.primary.opacity(0.022),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isOn ? tint.opacity(0.26) : Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PathCopyBehaviorCard: View {
    let title: String
    let result: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.cyan)
                .frame(width: 32, height: 32)
                .background(Color.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(result)
                    .font(.callout.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.022), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.075), lineWidth: 1)
        }
    }
}

private struct SettingsSubsectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct QuickActionToggleCard: View {
    let title: String
    let iconName: String
    let fallbackSystemImage: String
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            actionIcon
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.callout.weight(.semibold))

            Spacer(minLength: 6)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(!isEnabled)
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(
            isOn && isEnabled ? Color.indigo.opacity(0.06) : Color.primary.opacity(0.022),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isOn && isEnabled ? Color.indigo.opacity(0.22) : Color.primary.opacity(0.075), lineWidth: 1)
        }
        .opacity(isEnabled ? 1 : 0.58)
    }

    @ViewBuilder
    private var actionIcon: some View {
        if let image = Bundle.main.image(forResource: iconName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.indigo)
        }
    }
}

private struct MenuPlacementOptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        isSelected ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.045),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.42))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                isSelected ? Color.accentColor.opacity(0.075) : Color.primary.opacity(0.022),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.34) : Color.primary.opacity(0.075), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityHint(subtitle)
    }
}

struct TerminalApplicationPicker: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: model.selectedTerminalApplicationIcon)
                .resizable()
                .frame(width: 42, height: 42)
                .padding(9)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.blue.opacity(0.14), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text("当前终端应用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(model.selectedTerminalApplicationName)
                    .font(.headline)

                Text(model.selectedTerminalApplicationPathText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    model.chooseTerminalApplication()
                } label: {
                    Label("更换终端", systemImage: "folder")
                }
                .glassButtonStyle(prominent: true)

                Button {
                    model.resetTerminalApplication()
                } label: {
                    Label("恢复默认", systemImage: "arrow.counterclockwise")
                }
                .disabled(!model.hasCustomTerminalApplication)
                .glassButtonStyle()
            }
            .fixedSize()
        }
        .padding(14)
        .background(Color.primary.opacity(0.022), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct LanguageSelectionSheet: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(minimum: 180), spacing: 12),
        GridItem(.flexible(minimum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("选择软件语言")
                    .font(.title3.weight(.bold))
                Text("以下语言将在未来版本逐步支持，当前仅展示选择入口。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(quickDocLanguageOptions) { option in
                    Button {
                        model.showLanguageComingSoon(languageName: option.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(option.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .glassButtonStyle()
            }
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 320)
    }
}
