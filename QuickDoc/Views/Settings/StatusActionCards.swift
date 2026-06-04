import SwiftUI

struct PermissionStatusCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        let status = model.extensionStatus

        GlassSection {
            HStack(alignment: .center, spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("系统扩展权限")
                            .font(.headline)
                        Text(status.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.shield")
                }

                Spacer()

                Text(status.badgeTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(status.backgroundTint, in: Capsule())

                Button("打开系统设置") {
                    model.openExtensionSettings()
                }
                .glassButtonStyle()
            }
        }
    }
}

struct FinderRestartCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel

    var body: some View {
        GlassSection {
            HStack(spacing: 16) {
                Label {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("重启访达")
                            .font(.headline)
                        Text("当右键菜单未更新时，可重启 Finder 使扩展生效")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "folder.badge.gearshape")
                }

                Spacer()

                Button("立即重启 Finder") {
                    model.restartFinder()
                }
                .disabled(model.isRestartingFinder)
                .glassButtonStyle(prominent: true)
            }
        }
    }
}
