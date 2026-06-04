import SwiftUI

struct GeneralSettingsPage: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(title: "通用设置", subtitle: "管理 QuickDoc 的启动行为与基础偏好。")

            GlassSection {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("开机自启动", isOn: $model.launchAtLogin)
                    Text("登录 macOS 时自动启动 QuickDoc。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    Toggle("静默启动", isOn: $model.silentLaunchAtLogin)
                        .disabled(!model.launchAtLogin)
                    Text("开启后，登录 macOS 时在后台运行，不弹出软件主界面。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            DisplayModeSettingsCard()
            QuickAccessSettingsCard()
            LanguageSettingsCard()
            SoftwareUpdateSettingsCard()
        }
    }
}

struct DisplayModeSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("显示方式")
                        .font(.headline)
                    Text("控制 QuickDoc 在菜单栏与 Dock 中的显示方式，默认推荐常驻菜单栏。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    ForEach(QuickDocDisplayMode.allCases) { mode in
                        Button {
                            model.requestDisplayModeChange(mode)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: model.displayMode == mode ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(model.displayMode == mode ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mode.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(mode.subtitle)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(model.displayMode == mode ? Color.accentColor.opacity(0.10) : Color.clear)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(model.displayMode == mode ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
