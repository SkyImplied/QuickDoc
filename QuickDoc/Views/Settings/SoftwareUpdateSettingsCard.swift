import SwiftUI

struct SoftwareUpdateSettingsCard: View {
    @EnvironmentObject private var model: QuickDocSettingsModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("软件更新")
                            .font(.headline)
                        Text("当前版本 v\(model.appVersion)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(model.softwareUpdateButtonTitle) {
                        model.checkForSoftwareUpdate()
                    }
                    .disabled(model.isSoftwareUpdateInProgress)
                    .glassButtonStyle(prominent: true)
                }

                if model.isSoftwareUpdateInProgress {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(model.softwareUpdateStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label {
                    Text("QuickDoc 托管于 GitHub，可下载 DMG 覆盖安装或点击上方按钮自动更新；请确保网络可稳定访问 GitHub，否则可能超时。")
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
        }
    }

    private var warningColor: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.79, blue: 0.20)
            : Color(red: 0.66, green: 0.39, blue: 0.00)
    }
}
