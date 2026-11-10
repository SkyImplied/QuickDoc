import SwiftUI

struct EfficiencyToolsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: L("效率工具"))
            QuickAccessSettingsCard()
        }
    }
}

struct QuickAccessSettingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TerminalDirectSettingsCard()
            PathCopySettingsCard()
            QuickActionsSettingsCard()
            ExternalVolumeContextMenuCard()
        }
    }
}

struct TerminalDirectSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        EfficiencyGroup(title: L("终端直达"), systemImage: "terminal.fill") {
            EfficiencyToggleRow(
                title: L("在终端中打开"),
                caption: L("显示在 Finder 右键一级菜单。"),
                systemImage: "terminal.fill",
                isOn: $model.terminalDirectEnabled
            )
            Divider()
            TerminalApplicationPicker()
        }
    }
}

struct PathCopySettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        EfficiencyGroup(title: L("路径复制"), systemImage: "doc.on.doc") {
            EfficiencyToggleRow(
                title: L("复制当前路径"),
                caption: L("空白处复制当前文件夹，选中项复制所选路径。"),
                systemImage: "doc.on.doc",
                isOn: $model.pathCopyEnabled
            )
        }
    }
}

struct QuickActionsSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            copyPasteCutGroup
            permanentDeleteGroup
            menuPlacementGroup
        }
    }

    private var hasEnabledOperations: Bool {
        model.quickActionsEnabled || model.permanentDeleteEnabled
    }

    private var copyPasteCutGroup: some View {
        EfficiencyGroup(title: L("拷贝、粘贴与剪切"), systemImage: "square.on.square") {
            VStack(alignment: .leading, spacing: 0) {
                EfficiencyToggleRow(
                    title: L("在右键菜单中显示"),
                    caption: model.quickActionsEnabled ? nil : L("需先开启拷贝、粘贴与剪切"),
                    systemImage: "square.on.square",
                    isOn: $model.quickActionsEnabled,
                    accessibilityTitle: L("拷贝、粘贴与剪切")
                )

                childAction(
                    title: L("拷贝"),
                    systemImage: "doc.on.doc",
                    isOn: $model.copyActionEnabled
                )
                childAction(
                    title: L("粘贴"),
                    systemImage: "doc.on.clipboard",
                    isOn: $model.pasteActionEnabled
                )
                childAction(
                    title: L("剪切"),
                    systemImage: "scissors",
                    isOn: $model.cutActionEnabled
                )

                QuickActionsCompatibilityNotice()
                    .padding(.top, 8)
            }
        }
    }

    private func childAction(title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.leading, 40)
                .padding(.vertical, 4)
            EfficiencyToggleRow(
                title: title,
                systemImage: systemImage,
                isOn: isOn,
                isEnabled: model.quickActionsEnabled,
                indentsLabel: true
            )
        }
    }

    private var permanentDeleteGroup: some View {
        EfficiencyGroup(title: L("彻底删除"), systemImage: "trash.slash", iconColor: .red) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "trash.slash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(width: 18, height: 18)
                Text(L("永久删除，执行前会再次确认。"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle("", isOn: $model.permanentDeleteEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .accessibilityLabel(L("彻底删除"))
            }
            .padding(.vertical, 2)
        }
    }

    private var menuPlacementGroup: some View {
        EfficiencyGroup(title: L("菜单显示位置"), systemImage: "list.bullet") {
            VStack(alignment: .leading, spacing: 8) {
                if !hasEnabledOperations {
                    Text(L("启用任一文件操作后可设置"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 8) {
                    MenuPlacementOptionCard(
                        title: L("收起显示"),
                        subtitle: L("归入“快捷操作”"),
                        systemImage: "rectangle.stack",
                        isSelected: !model.quickActionsExpanded,
                        isEnabled: hasEnabledOperations
                    ) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            model.quickActionsExpanded = false
                        }
                    }

                    MenuPlacementOptionCard(
                        title: L("一级菜单"),
                        subtitle: L("直接出现在右键菜单"),
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
}

struct ExternalVolumeContextMenuCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        EfficiencyGroup(title: L("外置硬盘右键菜单（实验性）"), systemImage: "externaldrive") {
            EfficiencyToggleRow(
                title: L("在外置硬盘中显示"),
                systemImage: "externaldrive",
                isOn: $model.externalVolumeContextMenuEnabled,
                accessibilityTitle: L("外置硬盘右键菜单（实验性）")
            )
            Text(L("不建议开启。开启后会监听外置硬盘，系统可能将磁盘图标显示为 QuickDoc Logo；介意图标变化请保持关闭，建议将 QuickDoc 添加到访达工具栏使用。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L("关闭后，Finder 可能仍暂时保留已更换的图标，直到重新读取该磁盘。"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct QuickActionsCompatibilityNotice: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text(L("拷贝、粘贴、剪切需配套使用，与 Finder 原菜单不互通。"))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(warningColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(colorScheme == .dark ? 0.10 : 0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.yellow.opacity(colorScheme == .dark ? 0.22 : 0.30), lineWidth: 1)
        }
    }

    private var warningColor: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.79, blue: 0.20)
            : Color(red: 0.66, green: 0.39, blue: 0.00)
    }
}

private struct EfficiencyGroup<Content: View>: View {
    let title: String
    let systemImage: String
    var iconColor: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22, height: 22)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GlassSection {
                VStack(alignment: .leading, spacing: 8) {
                    content
                }
            }
        }
    }
}

private struct EfficiencyToggleRow: View {
    let title: String
    var caption: String?
    let systemImage: String
    var iconColor: Color = .secondary
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var indentsLabel = false
    var accessibilityTitle: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isEnabled ? iconColor : Color.secondary)
                .frame(width: 18, height: 18)
                .padding(.leading, indentsLabel ? 22 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isEnabled)
                .accessibilityLabel(accessibilityTitle ?? title)
        }
        .padding(.vertical, 2)
        .opacity(isEnabled ? 1 : 0.72)
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected && isEnabled ? Color.primary : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                Color.primary.opacity(isSelected && isEnabled ? 0.07 : 0.035),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(isSelected && isEnabled ? 0.22 : 0.08), lineWidth: isSelected && isEnabled ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? L("已选择") : L("未选择"))
    }
}

struct TerminalApplicationPicker: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            pickerRow(stacksButtons: false)
            pickerRow(stacksButtons: true)
        }
        .padding(.vertical, 2)
    }

    private func pickerRow(stacksButtons: Bool) -> some View {
        let info = HStack(alignment: .center, spacing: 10) {
            Image(nsImage: model.selectedTerminalApplicationIcon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedTerminalApplicationName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(model.selectedTerminalApplicationPathText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        let buttons = HStack(spacing: 8) {
            Button {
                model.chooseTerminalApplication()
            } label: {
                Label(L("更换终端"), systemImage: "folder")
            }
            .glassButtonStyle(prominent: true)

            Button {
                model.resetTerminalApplication()
            } label: {
                Label(L("恢复默认"), systemImage: "arrow.counterclockwise")
            }
            .disabled(!model.hasCustomTerminalApplication)
            .glassButtonStyle()
        }
        .fixedSize(horizontal: true, vertical: false)

        return Group {
            if stacksButtons {
                VStack(alignment: .leading, spacing: 8) {
                    info
                    buttons
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    info
                    buttons
                }
            }
        }
    }
}
