import SwiftUI

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
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "command")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("终端直达")
                            .font(.headline)
                        Text("开启后会在 Finder 右键一级菜单显示“在终端中打开”。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("启用终端直达", isOn: $model.terminalDirectEnabled)

                Divider()

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
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("路径复制")
                            .font(.headline)
                        Text("开启后会在 Finder 右键一级菜单显示“复制当前路径”。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("启用路径复制", isOn: $model.pathCopyEnabled)

                Text("未选中文件时复制当前文件夹路径；选中文件或文件夹时复制所选项目路径。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct QuickActionsSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("快捷操作")
                            .font(.headline)
                        Text("选择 Finder 右键菜单中要显示的操作，并决定是在一级菜单展示还是收起。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Toggle("启用拷贝、粘贴和剪切", isOn: $model.quickActionsEnabled)

                Toggle("展开快捷操作", isOn: $model.quickActionsExpanded)
                    .disabled(!model.quickActionsEnabled && !model.permanentDeleteEnabled)

                Text(model.quickActionsExpanded ? "已启用的操作会直接显示在 Finder 右键一级菜单。" : "已启用的操作会收起在 Finder 右键菜单的“快捷操作”中。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("显示的常用操作")
                        .font(.callout.weight(.semibold))

                    QuickActionPreferenceRow(
                        title: "拷贝",
                        iconName: "复制",
                        fallbackSystemImage: "doc.on.doc",
                        isOn: $model.copyActionEnabled
                    )
                    QuickActionPreferenceRow(
                        title: "粘贴",
                        iconName: "粘贴",
                        fallbackSystemImage: "clipboard",
                        isOn: $model.pasteActionEnabled
                    )
                    QuickActionPreferenceRow(
                        title: "剪切",
                        iconName: "剪切",
                        fallbackSystemImage: "scissors",
                        isOn: $model.cutActionEnabled
                    )
                }
                .disabled(!model.quickActionsEnabled)

                Divider()

                QuickActionPreferenceRow(
                    title: "彻底删除",
                    subtitle: "永久删除所选文件或文件夹，不会移入废纸篓；执行前会再次确认。",
                    iconName: "彻底删除",
                    fallbackSystemImage: "trash.slash",
                    tint: .red,
                    isOn: $model.permanentDeleteEnabled
                )
            }
        }
    }
}

private struct QuickActionPreferenceRow: View {
    let title: String
    var subtitle: String?
    let iconName: String
    let fallbackSystemImage: String
    var tint: Color = .blue
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: 12) {
                actionIcon
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
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
                .foregroundStyle(tint)
        }
    }
}

struct TerminalApplicationPicker: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: model.selectedTerminalApplicationIcon)
                .resizable()
                .frame(width: 44, height: 44)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text("当前终端")
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
                Button("更换终端 App") {
                    model.chooseTerminalApplication()
                }
                .glassButtonStyle(prominent: true)

                Button("恢复系统终端") {
                    model.resetTerminalApplication()
                }
                .disabled(!model.hasCustomTerminalApplication)
                .glassButtonStyle()
            }
            .fixedSize()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
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
